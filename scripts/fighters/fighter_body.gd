class_name FighterBody
extends CharacterBody2D

signal stamina_changed(current: float, maximum: float)
signal punch_started(direction: Vector2)
signal punch_finished(connected: bool)
signal punch_swung(attack: BoxingAttack)
signal hit_landed(point: Vector2, direction: Vector2, attack: BoxingAttack, blocked: bool)
signal cross_charge_changed(ratio: float, charging: bool)
signal defense_resolved(blocked: bool, guard_broken: bool)
signal guard_break_changed(broken: bool)
signal dodge_cooldown_changed(remaining: float, total: float)
signal combo_connected(title: String, bonus_damage: float, point: Vector2)
signal counter_connected(bonus_damage: float)

const COUNTER_WINDOW: float = 0.45
const COUNTER_DAMAGE_SCALE: float = 1.25
const ALTERNATE_BUFFER_EXTRA: float = 0.06
const BURST_LIMIT: int = 3
const BURST_RECOVERY_EXTRA: float = 0.18
const EXHAUSTION_RECOVERY_RATIO: float = 0.12

enum AttackState { IDLE, WINDUP, ACTIVE, RECOVERY, CHARGING, CROSS_PENDING, DODGING, DODGE_RECOVERY }

@export_group("Combate")
@export var combat_enabled: bool = true
@export var body_color := Color("4fd1b0")
@export_flags_2d_physics var attack_collision_mask: int = 2
@export_range(0.0, 1.0) var blocked_damage_ratio: float = 0.25
@export var guard_stamina_ratio: float = 0.8
@export_group("Guardia")
@export_range(0.1, 1.0) var guard_break_duration: float = 0.45
@export_range(0.0, 1.0) var guard_break_move_ratio: float = 0.4
@export_range(0.0, 1.0) var guarding_regen_ratio: float = 0.35
@export_group("Esquiva")
@export_range(1.0, 100.0) var dodge_cost: float = 18.0
@export_range(100.0, 500.0) var dodge_speed: float = 300.0
@export_range(0.05, 0.4) var dodge_duration: float = 0.18
@export_range(0.05, 0.5) var dodge_recovery: float = 0.16
@export_range(0.2, 2.0) var dodge_cooldown: float = 0.65
@export_range(0.0, 0.2) var dodge_evade_start: float = 0.03
@export_range(0.0, 0.4) var dodge_evade_end: float = 0.13

@export_group("Movimiento")
@export var walk_speed: float = 150.0
@export var sprint_speed: float = 240.0
@export var acceleration: float = 2200.0
@export var braking: float = 2800.0
@export var target: Node2D
@export_group("Empuje físico")
@export_range(100.0, 3000.0) var knockback_drag: float = 1000.0
@export_range(0.0, 500.0) var max_knockback_speed: float = 260.0
@export_range(0.0, 1.0) var blocked_knockback_ratio: float = 0.25
@export_group("Estamina")
@export_range(1.0, 1000.0) var max_stamina: float = 300.0
@export var sprint_drain: float = 22.0
@export var stamina_regen: float = 30.0
@export var regen_delay: float = 0.6
@export_group("Golpes")
@export var jab: BoxingAttack = preload("res://resources/attacks/jab.tres")
@export var cross: BoxingAttack = preload("res://resources/attacks/cross.tres")
@export_range(0.05, 0.25) var input_buffer_window: float = 0.14
@export_group("Combos")
@export_range(0.4, 1.5) var combo_hit_window: float = 0.85
@export var combos: Array[BoxingCombo] = [
	preload("res://resources/combos/one_two.tres"),
	preload("res://resources/combos/double_jab_cross.tres"),
	preload("res://resources/combos/return_jab.tres"),
]
@export_group("Carga del cross")
@export_range(0.0, 0.3) var charge_tap_grace: float = 0.18
@export_range(0.2, 2.0) var charge_duration: float = 0.9
@export_range(1.0, 3.0) var max_charge_damage_scale: float = 2.0
@export_range(1.0, 3.0) var max_charge_cost_scale: float = 2.0

var stamina: float = 0.0
var facing_direction: Vector2 = Vector2.RIGHT
var attack_state: AttackState = AttackState.IDLE
var is_blocking: bool = false
var _touch_block_held: bool = false
var _attack: BoxingAttack
var _regen_time_left: float = 0.0
var _exhausted: bool = false
var _touch_direction: Vector2 = Vector2.ZERO
var _attack_elapsed: float = 0.0
var _attack_direction: Vector2 = Vector2.RIGHT
var _hit_targets: Dictionary = {}
var _hit_query := PhysicsShapeQueryParameters2D.new()
var _hit_shape := CapsuleShape2D.new()
var _impact_pause_left: float = 0.0
var _queued_attack: BoxingAttack
var _buffer_left: float = 0.0
var _step_phase: float = 0.0
var _charge_elapsed: float = 0.0
var _touch_cross_held: bool = false
var _cross_input_held: bool = false
var _queued_charge: bool = false
var _guard_break_left: float = 0.0
var _damage_flash_left: float = 0.0
var _visual_recoil_offset := Vector2.ZERO
var _move_velocity := Vector2.ZERO
var _knockback_velocity := Vector2.ZERO
var _dodge_direction := Vector2.ZERO
var _dodge_elapsed: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _last_hit_blocked: bool = false
var _combo_tracker := ComboTracker.new()
var _redraw_busy: bool = true
@onready var health: HealthComponent = $Health

var _counter_time_left: float = 0.0
var _counter_target_id: int = 0
var _miss_punished: bool = false
var _evaded_targets: Dictionary = {}
var _burst_count: int = 0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_combo_tracker.configure(combos, combo_hit_window)
	_attack = jab
	_hit_query.shape = _hit_shape
	_hit_query.collision_mask = attack_collision_mask
	_hit_query.collide_with_areas = true
	_hit_query.collide_with_bodies = false
	stamina = max_stamina
	stamina_changed.emit(stamina, max_stamina)

func _physics_process(delta: float) -> void:
	_damage_flash_left = maxf(0.0, _damage_flash_left - delta)
	if not can_fight():
		if attack_state != AttackState.IDLE or _queued_attack != null or _impact_pause_left > 0.0 or not velocity.is_zero_approx() or _touch_block_held or _touch_cross_held or _cross_input_held:
			stop_combat()
		_visual_recoil_offset = _visual_recoil_offset.move_toward(Vector2.ZERO, 65.0 * delta)
		_queue_fighter_redraw(_damage_flash_left > 0.0 or not _visual_recoil_offset.is_zero_approx())
		return
	# La pulsación pendiente comparte el reloj local de la recuperación.
	if _impact_pause_left <= 0.0:
		_combo_tracker.advance(delta)
		_counter_time_left = maxf(0.0, _counter_time_left - delta)
		_buffer_left = maxf(0.0, _buffer_left - delta)
	if _buffer_left <= 0.0:
		clear_queued_attack()
	var direction: Vector2 = _get_move_direction()
	_update_facing(direction)
	is_blocking = attack_state == AttackState.IDLE and _guard_break_left <= 0.0 and _is_block_held()
	_poll_attack_input()
	if _is_block_held():
		_combo_tracker.reset()
		clear_queued_attack()
		cancel_cross_charge()
		is_blocking = attack_state == AttackState.IDLE and _guard_break_left <= 0.0
	# Pausa local: la interfaz, el sonido y las entradas siguen activos.
	if _impact_pause_left > 0.0:
		_impact_pause_left = maxf(0.0, _impact_pause_left - delta)
		velocity = Vector2.ZERO
		_move_velocity = Vector2.ZERO
		_queue_fighter_redraw(true)
		return
	_regen_time_left = maxf(0.0, _regen_time_left - delta)
	if _dodge_cooldown_left > 0.0:
		_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
		dodge_cooldown_changed.emit(_dodge_cooldown_left, dodge_cooldown)
	if has_guard_break():
		_guard_break_left = maxf(0.0, _guard_break_left - delta)
		if not has_guard_break():
			is_blocking = attack_state == AttackState.IDLE and _is_block_held()
			guard_break_changed.emit(false)
	_visual_recoil_offset = _visual_recoil_offset.move_toward(Vector2.ZERO, 65.0 * delta)
	var running: bool = (
		_is_sprint_held() and not direction.is_zero_approx()
		and not is_exhausted() and attack_state == AttackState.IDLE and not is_blocking
		and not has_guard_break()
	)
	var run_cost: float = sprint_drain * delta
	if running:
		running = stamina >= run_cost
		_spend_stamina(run_cost)
	var speed: float = sprint_speed if running else walk_speed
	if is_dodge_busy():
		speed *= 0.4
	elif has_guard_break():
		speed *= guard_break_move_ratio
	elif attack_state == AttackState.CHARGING:
		speed *= 0.4
	elif attack_state != AttackState.IDLE:
		speed *= 0.55
	elif is_blocking:
		speed *= 0.45
	var target_velocity: Vector2 = direction * speed
	var rate: float = braking if direction.is_zero_approx() else acceleration
	# Movimiento voluntario y empuje se frenan por separado: el joystick
	# no borra el impacto y varios golpes no acumulan velocidad sin límite.
	_move_velocity = _move_velocity.move_toward(target_velocity, rate * delta)
	if attack_state == AttackState.DODGING:
		_move_velocity = _dodge_direction * dodge_speed
	velocity = _move_velocity + _knockback_velocity
	move_and_slide()
	for index in get_slide_collision_count():
		var normal: Vector2 = get_slide_collision(index).get_normal()
		if _knockback_velocity.dot(normal) < 0.0:
			_knockback_velocity = _knockback_velocity.slide(normal)
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_drag * delta)
	_step_phase += get_position_delta().length() * 0.13
	_update_attack(delta)
	if not running and attack_state == AttackState.IDLE and _regen_time_left <= 0.0:
		if not has_guard_break():
			_set_stamina(stamina + stamina_regen * delta * (guarding_regen_ratio if is_blocking else 1.0))
	_queue_fighter_redraw(
		attack_state != AttackState.IDLE
		or is_blocking
		or has_guard_break()
		or _counter_time_left > 0.0
		or _damage_flash_left > 0.0
		or not _visual_recoil_offset.is_zero_approx()
		or velocity.length_squared() > 4.0
	)

# El controlador humano y el rival solo cambian estas fuentes de intención.
func _get_move_direction() -> Vector2:
	return _touch_direction

func _is_block_held() -> bool:
	return _touch_block_held

func _is_cross_held() -> bool:
	return _touch_cross_held

func _is_sprint_held() -> bool:
	return false

func _poll_attack_input() -> void:
	_sync_cross_input()

func can_fight() -> bool:
	return combat_enabled and is_instance_valid(health) and health.current_health > 0.0

func is_dodge_busy() -> bool:
	return attack_state in [AttackState.DODGING, AttackState.DODGE_RECOVERY]

func is_evading() -> bool:
	return can_fight() and attack_state == AttackState.DODGING and _dodge_elapsed >= dodge_evade_start and _dodge_elapsed < minf(dodge_evade_end, dodge_duration)

func get_dodge_cooldown_remaining() -> float:
	return _dodge_cooldown_left

func request_dodge() -> bool:
	if not can_fight() or attack_state != AttackState.IDLE or has_guard_break() or is_hit_paused() or is_exhausted():
		return false
	if _dodge_cooldown_left > 0.0 or stamina < dodge_cost:
		return false
	_update_facing(_get_move_direction())
	_dodge_direction = _get_move_direction().normalized()
	if _dodge_direction.is_zero_approx():
		_dodge_direction = -facing_direction
	_dodge_elapsed = 0.0
	_dodge_cooldown_left = dodge_cooldown
	dodge_cooldown_changed.emit(_dodge_cooldown_left, dodge_cooldown)
	clear_queued_attack()
	_combo_tracker.reset()
	is_blocking = false
	_spend_stamina(dodge_cost)
	attack_state = AttackState.DODGING
	queue_redraw()
	return true

func _update_dodge(delta: float) -> void:
	_dodge_elapsed += delta
	_regen_time_left = regen_delay
	if _dodge_elapsed >= dodge_duration + dodge_recovery:
		attack_state = AttackState.IDLE
		_move_velocity = Vector2.ZERO
	elif attack_state == AttackState.DODGING and _dodge_elapsed >= dodge_duration:
		attack_state = AttackState.DODGE_RECOVERY
		_move_velocity = Vector2.ZERO

func _cancel_dodge() -> void:
	if is_dodge_busy():
		attack_state = AttackState.IDLE
		_dodge_elapsed = 0.0
		_move_velocity = Vector2.ZERO
		velocity = Vector2.ZERO

func is_hit_paused() -> bool:
	return _impact_pause_left > 0.0

func has_guard_break() -> bool:
	return _guard_break_left > 0.0

func get_guard_break_remaining() -> float:
	return _guard_break_left

func _break_guard() -> void:
	clear_queued_attack()
	cancel_cross_charge()
	_combo_tracker.reset()
	_cross_input_held = _is_cross_held()
	_guard_break_left = guard_break_duration
	is_blocking = false
	_move_velocity = Vector2.ZERO
	guard_break_changed.emit(true)

func remaining_recovery(next_attack: BoxingAttack = null) -> float:
	return _get_recovery_end(next_attack) - _attack_elapsed

func clear_queued_attack() -> void:
	_queued_attack = null
	_queued_charge = false
	_buffer_left = 0.0

func stop_combat() -> void:
	var was_guard_broken: bool = has_guard_break()
	_combo_tracker.reset()
	_counter_time_left = 0.0
	_counter_target_id = 0
	_miss_punished = false
	_evaded_targets.clear()
	_burst_count = 0
	cancel_cross_charge()
	attack_state = AttackState.IDLE
	clear_queued_attack()
	_touch_direction = Vector2.ZERO
	_touch_block_held = false
	_touch_cross_held = false
	# Una tecla aún mantenida no debe relanzar el cross al detener el combate.
	_cross_input_held = _is_cross_held()
	is_blocking = false
	velocity = Vector2.ZERO
	_move_velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	_dodge_direction = Vector2.ZERO
	_dodge_elapsed = 0.0
	_dodge_cooldown_left = 0.0
	dodge_cooldown_changed.emit(0.0, dodge_cooldown)
	_impact_pause_left = 0.0
	_guard_break_left = 0.0
	_attack_elapsed = 0.0
	_charge_elapsed = 0.0
	_hit_targets.clear()
	if _exhausted:
		_exhausted = false
		stamina_changed.emit(stamina, max_stamina)
	if was_guard_broken:
		guard_break_changed.emit(false)
	_queue_fighter_redraw(true)

func is_guarding_direction(direction: Vector2) -> bool:
	var front: bool = not direction.is_zero_approx() and facing_direction.dot(-direction.normalized()) >= cos(deg_to_rad(70.0))
	return can_fight() and attack_state == AttackState.IDLE and _guard_break_left <= 0.0 and _is_block_held() and front

func receive_attack(damage: float, direction: Vector2, recoil: float, pause: float, knockback: float = 0.0) -> bool:
	if not can_fight() or damage <= 0.0:
		return false
	if is_evading():
		return false
	# Un impacto fuera de la ventana evasiva corta el paso y conserva
	# una recuperación breve; no permite cancelar el daño atacando.
	if attack_state == AttackState.DODGING:
		attack_state = AttackState.DODGE_RECOVERY
		_dodge_elapsed = dodge_duration
		_move_velocity = Vector2.ZERO
	var blocked: bool = is_guarding_direction(direction)
	var broken: bool = false
	if blocked:
		var cost: float = damage * guard_stamina_ratio
		if stamina >= cost:
			_spend_stamina(cost)
			damage *= blocked_damage_ratio
		else:
			_spend_stamina(stamina)
			_break_guard()
			blocked = false
			broken = true
	if not health.apply_damage(damage, not blocked):
		return false
	if not blocked:
		_combo_tracker.reset()
		_counter_time_left = 0.0
	# apply_damage puede cerrar el combate mediante señales de KO.
	# No reintroducir movimiento después de que stop_combat lo haya limpiado.
	if can_fight():
		var push: float = clampf(knockback, 0.0, max_knockback_speed)
		push *= blocked_knockback_ratio if blocked else 1.0
		_knockback_velocity = (direction.normalized() * push).limit_length(max_knockback_speed)
	_last_hit_blocked = blocked
	_damage_flash_left = 0.12
	_visual_recoil_offset = direction.normalized() * recoil * (0.4 if blocked else 1.0)
	_impact_pause_left = maxf(_impact_pause_left, pause * (0.5 if blocked else 1.0))
	defense_resolved.emit(blocked, broken)
	queue_redraw()
	return true

func _update_facing(move_direction: Vector2) -> void:
	# El jab conserva la dirección elegida al iniciarlo.
	if attack_state not in [AttackState.IDLE, AttackState.CHARGING, AttackState.CROSS_PENDING]:
		return
	if is_instance_valid(target):
		var offset: Vector2 = target.global_position - global_position
		if not offset.is_zero_approx():
			facing_direction = offset.normalized()
	elif not move_direction.is_zero_approx():
		facing_direction = move_direction.normalized()

# El joystick debe enviar Vector2.ZERO cuando se suelta.
func set_touch_direction(direction: Vector2) -> void:
	_touch_direction = direction.limit_length(1.0)

func set_touch_block(held: bool) -> void:
	_touch_block_held = held
	is_blocking = can_fight() and attack_state == AttackState.IDLE and held and _guard_break_left <= 0.0
	if held:
		_combo_tracker.reset()
		clear_queued_attack()
		cancel_cross_charge()
		is_blocking = can_fight() and attack_state == AttackState.IDLE and _guard_break_left <= 0.0

func set_touch_cross(held: bool, canceled: bool = false) -> void:
	_touch_cross_held = held
	if canceled and not _is_cross_held():
		_cross_input_held = false
		cancel_cross_charge()
	else:
		_sync_cross_input()

# Teclado y touch comparten el gesto; soltar una fuente no suelta la otra.
func _sync_cross_input() -> void:
	var held: bool = _is_cross_held()
	if held == _cross_input_held:
		return
	_cross_input_held = held
	if held:
		_begin_cross_charge()
	else:
		_release_cross_charge()

func _begin_cross_charge() -> bool:
	if not can_fight() or _guard_break_left > 0.0 or is_exhausted():
		return false
	if _is_block_held() or stamina < cross.stamina_cost:
		return false
	if attack_state != AttackState.IDLE:
		# Un toque corto al final de otro ataque sigue sirviendo como combo.
		if _request_attack(cross):
			_queued_charge = true
			return true
		return false
	_attack = cross
	clear_queued_attack()
	_charge_elapsed = 0.0
	_attack_elapsed = 0.0
	# Empieza la preparación normal al pulsar. La intención de cargar se
	# confirma después del umbral; un tap nunca muestra el indicador de carga.
	attack_state = AttackState.CROSS_PENDING
	is_blocking = false
	return true

func get_cross_charge_ratio() -> float:
	var time_ratio: float = clampf((_charge_elapsed - charge_tap_grace) / charge_duration, 0.0, 1.0)
	var extra_cost: float = cross.stamina_cost * (max_charge_cost_scale - 1.0)
	var affordable_ratio: float = 1.0
	if extra_cost > 0.0:
		affordable_ratio = clampf((stamina - cross.stamina_cost) / extra_cost, 0.0, 1.0)
	return minf(time_ratio, affordable_ratio)

func _release_cross_charge() -> bool:
	if _queued_charge:
		_queued_charge = false # Conserva el cross normal ya guardado.
		return true
	if attack_state not in [AttackState.CHARGING, AttackState.CROSS_PENDING]:
		return false
	var was_charging: bool = attack_state == AttackState.CHARGING
	var prepared_time: float = minf(_charge_elapsed, maxf(0.0, cross.windup - 0.0001))
	var ratio: float = get_cross_charge_ratio()
	var charged_attack: BoxingAttack = cross
	if ratio > 0.0:
		# Copia por lanzamiento: nunca modifica el recurso compartido del cross.
		charged_attack = cross.duplicate() as BoxingAttack
		charged_attack.charge_ratio = ratio
		charged_attack.damage *= lerpf(1.0, max_charge_damage_scale, ratio)
		charged_attack.stamina_cost *= lerpf(1.0, max_charge_cost_scale, ratio)
		charged_attack.stamina_cost = minf(stamina, charged_attack.stamina_cost)
		charged_attack.recovery *= lerpf(1.0, 1.3, ratio)
		charged_attack.visual_recoil = lerpf(cross.visual_recoil, 12.0, ratio)
		charged_attack.knockback_speed *= lerpf(1.0, 1.5, ratio)
		charged_attack.impact_pause = lerpf(cross.impact_pause, 0.075, ratio)
		prepared_time = charged_attack.windup * 0.55
	attack_state = AttackState.IDLE
	_charge_elapsed = 0.0
	if was_charging:
		cross_charge_changed.emit(0.0, false)
	var started: bool = _start_attack(charged_attack)
	if started:
		# Conserva la preparación ya animada, en vez de volver al primer cuadro.
		_attack_elapsed = prepared_time
	return started

func cancel_cross_charge() -> void:
	if _queued_charge:
		clear_queued_attack()
	_queued_charge = false
	if attack_state in [AttackState.CHARGING, AttackState.CROSS_PENDING]:
		var was_charging: bool = attack_state == AttackState.CHARGING
		attack_state = AttackState.IDLE
		_burst_count = 0
		_charge_elapsed = 0.0
		_regen_time_left = regen_delay
		if was_charging:
			cross_charge_changed.emit(0.0, false)

# Solo guarda la última pulsación, cerca del final de la recuperación.
# Alternar manos permite cerrar un poco antes la recuperación, nunca el contacto.
# La estamina se cobra solo al iniciar el siguiente golpe.
func request_jab() -> bool:
	return _request_attack(jab)

func request_cross() -> bool:
	return _request_attack(cross)

func _request_attack(attack: BoxingAttack) -> bool:
	if not can_fight() or _guard_break_left > 0.0 or is_exhausted():
		return false
	if attack_state in [AttackState.CHARGING, AttackState.CROSS_PENDING]:
		return false
	if attack_state == AttackState.IDLE:
		return _start_attack(attack)
	if _is_block_held():
		return false
	var buffer_window: float = input_buffer_window
	if attack.glove_side != _attack.glove_side:
		buffer_window += ALTERNATE_BUFFER_EXTRA
	var remaining: float = _get_recovery_end(attack) - _attack_elapsed
	if attack_state != AttackState.RECOVERY or remaining > buffer_window:
		return false
	_queued_attack = attack
	_queued_charge = false
	# La cola se revisa al inicio del paso y la recuperación al final.
	_buffer_left = buffer_window + get_physics_process_delta_time()
	return true

func _get_recovery_end(next_attack: BoxingAttack = null) -> float:
	var recovery: float = _attack.recovery
	if _burst_count >= BURST_LIMIT:
		recovery += BURST_RECOVERY_EXTRA
	elif next_attack != null and next_attack.glove_side != _attack.glove_side:
		if stamina >= next_attack.stamina_cost and not _is_block_held():
			recovery = maxf(0.04, recovery - _attack.alternate_recovery_credit)
	return _attack.windup + _attack.active + recovery

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_dodge()
		_combo_tracker.reset()
		cancel_cross_charge()
		clear_queued_attack()
		_touch_direction = Vector2.ZERO
		_touch_block_held = false
		is_blocking = false
		_touch_cross_held = false
		# Una tecla aún mantenida debe soltarse antes de poder volver a cargar.
		_cross_input_held = _is_cross_held()

func try_punch() -> bool:
	return _start_attack(jab)

func try_cross() -> bool:
	return _start_attack(cross)

func _start_attack(attack: BoxingAttack) -> bool:
	if not can_fight() or _guard_break_left > 0.0 or is_exhausted():
		return false
	if attack_state != AttackState.IDLE or _is_block_held():
		return false
	if attack == null or stamina < attack.stamina_cost:
		return false
	_update_facing(Vector2.ZERO)
	_attack = attack
	clear_queued_attack()
	is_blocking = false
	_spend_stamina(attack.stamina_cost)
	_attack_elapsed = 0.0
	_attack_direction = facing_direction
	_hit_targets.clear()
	attack_state = AttackState.WINDUP
	_burst_count += 1
	_evaded_targets.clear()
	_miss_punished = false
	punch_started.emit(_attack_direction)
	return true

func _is_open_to_counter() -> bool:
	return attack_state == AttackState.RECOVERY and _hit_targets.is_empty() and not _miss_punished

func _open_dodge_counter(attacker_id: int) -> void:
	_counter_target_id = attacker_id
	_counter_time_left = COUNTER_WINDOW

func _update_attack(delta: float) -> void:
	if is_dodge_busy():
		_update_dodge(delta)
		return
	if attack_state == AttackState.CROSS_PENDING:
		_charge_elapsed += delta
		_attack_elapsed = minf(_charge_elapsed, maxf(0.0, cross.windup - 0.0001))
		_regen_time_left = regen_delay
		if _charge_elapsed >= charge_tap_grace:
			attack_state = AttackState.CHARGING
			_burst_count = 0
			cross_charge_changed.emit(get_cross_charge_ratio(), true)
		return
	if attack_state == AttackState.CHARGING:
		_charge_elapsed = minf(_charge_elapsed + delta, charge_tap_grace + charge_duration)
		if get_cross_charge_ratio() > 0.0:
			_combo_tracker.reset() # La carga y el bonus de combo no se multiplican.
		_regen_time_left = regen_delay # No se regenera estamina mientras carga.
		cross_charge_changed.emit(get_cross_charge_ratio(), true)
		return
	if attack_state == AttackState.IDLE:
		return
	var previous_time: float = _attack_elapsed
	_attack_elapsed += delta
	var active_end: float = _attack.windup + _attack.active
	if previous_time < _attack.windup and _attack_elapsed >= _attack.windup:
		punch_swung.emit(_attack)
	# Detecta también el cruce de la ventana activa en un paso de física largo.
	if _attack_elapsed >= _attack.windup and previous_time < active_end:
		_check_attack_hits()
	if _attack_elapsed >= _get_recovery_end(_queued_attack):
		var burst_complete: bool = _burst_count >= BURST_LIMIT
		if _hit_targets.is_empty() or burst_complete:
			_combo_tracker.reset()
		attack_state = AttackState.IDLE
		punch_finished.emit(not _hit_targets.is_empty())
		var next_attack: BoxingAttack = _queued_attack
		var begin_charge: bool = _queued_charge and _cross_input_held
		var buffer_valid: bool = _buffer_left > 0.0
		clear_queued_attack()
		if burst_complete:
			_burst_count = 0
		if next_attack != null and buffer_valid:
			if begin_charge:
				if _begin_cross_charge():
					return
			elif _start_attack(next_attack):
				return
		_burst_count = 0
	elif _attack_elapsed >= active_end:
		attack_state = AttackState.RECOVERY
	elif _attack_elapsed >= _attack.windup:
		attack_state = AttackState.ACTIVE

func _check_attack_hits() -> void:
	_hit_shape.radius = _attack.radius
	# Barre el recorrido frontal del guante: ampliar alcance no deja un hueco
	# entre el cuerpo y el puño extendido. La cápsula conserva el ancho del golpe.
	var start_reach: float = minf(19.0, _attack.reach)
	_hit_shape.height = _attack.reach - start_reach + _attack.radius * 2.0
	var fist_position: Vector2 = global_position + _attack_direction * _attack.reach
	fist_position += _attack_direction.orthogonal() * 11.0 * _attack.glove_side
	var sweep_center: Vector2 = fist_position - _attack_direction * (_attack.reach - start_reach) * 0.5
	# CapsuleShape2D es vertical en su espacio local.
	_hit_query.transform = Transform2D(_attack_direction.angle() - PI * 0.5, sweep_center)
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(_hit_query):
		var hurtbox := result["collider"] as CombatHurtbox
		if hurtbox == null or not is_instance_valid(hurtbox.health) or hurtbox.health == health:
			continue
		var target_id: int = hurtbox.health.get_instance_id()
		if _hit_targets.has(target_id):
			continue
		var defender := hurtbox.defender as FighterBody
		if is_instance_valid(defender) and defender.is_evading():
			if not _evaded_targets.has(target_id):
				_evaded_targets[target_id] = true
				defender._open_dodge_counter(health.get_instance_id())
			continue
		var guarded: bool = hurtbox.is_guarding(_attack_direction)
		var eligible: bool = not guarded and _attack.charge_ratio <= 0.0
		var combo: BoxingCombo = _combo_tracker.preview(_attack.attack_id, target_id) if eligible else null
		var punish_miss: bool = is_instance_valid(defender) and defender._is_open_to_counter()
		var punish_dodge: bool = _counter_time_left > 0.0 and _counter_target_id == target_id
		var counter: bool = eligible and combo == null and (punish_miss or punish_dodge)
		var damage: float = _attack.damage * (combo.finisher_damage_scale if combo != null else 1.0)
		if counter:
			damage *= COUNTER_DAMAGE_SCALE
		var health_before_hit: float = hurtbox.health.current_health
		if hurtbox.receive_hit(damage, _attack_direction, _attack.visual_recoil, _attack.impact_pause, _attack.get_knockback_speed(damage)):
			if not guarded:
				# Daño efectivo, incluido el combo; no cura por exceso sobre un KO.
				health.restore_from_damage(health_before_hit - hurtbox.health.current_health)
			_hit_targets[target_id] = true
			_impact_pause_left = maxf(_impact_pause_left, _attack.impact_pause)
			if eligible:
				_combo_tracker.record_clean_hit(_attack.attack_id, target_id)
			else:
				_combo_tracker.reset()
			var was_blocked: bool = is_instance_valid(defender) and defender._last_hit_blocked
			hit_landed.emit(fist_position, _attack_direction, _attack, was_blocked)
			if combo != null:
				combo_connected.emit(combo.title, damage - _attack.damage, fist_position)
			if counter:
				if punish_dodge:
					_counter_time_left = 0.0
				if punish_miss and is_instance_valid(defender):
					defender._miss_punished = true
				counter_connected.emit(damage - _attack.damage)

func _queue_fighter_redraw(busy: bool) -> void:
	if busy or _redraw_busy:
		queue_redraw()
	_redraw_busy = busy

func _spend_stamina(amount: float) -> void:
	_set_stamina(stamina - amount)
	_regen_time_left = regen_delay

func restore_stamina(amount: float) -> void:
	_set_stamina(stamina + maxf(0.0, amount))

func is_exhausted() -> bool:
	return stamina <= 0.0 or (_exhausted and stamina < max_stamina * EXHAUSTION_RECOVERY_RATIO)

func _set_stamina(value: float) -> void:
	var next_value: float = clampf(value, 0.0, max_stamina)
	if next_value == stamina:
		return
	stamina = next_value
	# Una reserva que tocó cero debe recuperarse antes de volver a gastar.
	_exhausted = is_exhausted()
	stamina_changed.emit(stamina, max_stamina)

func _draw() -> void:
	if _attack == null:
		return
	var lean: float = 0.0
	var twist: float = 0.0
	var reach: float = 19.0
	var glove_color := Color("ff786d")
	if _counter_time_left > 0.0:
		draw_arc(Vector2.ZERO, 34.0, -PI * 0.5, -PI * 0.5 + TAU * (_counter_time_left / COUNTER_WINDOW), 32, Color("f6be64"), 3.0, true)
	if is_dodge_busy():
		var color := Color("8de8cc") if is_evading() else Color("64788e")
		draw_arc(Vector2.ZERO, 25.0, 0, TAU, 24, color, 2.0, true)
		draw_line(-_dodge_direction * 18.0, -_dodge_direction * 32.0, color, 4.0, true)
	match attack_state:
		AttackState.CHARGING:
			var charge: float = get_cross_charge_ratio()
			var prepared: float = minf(charge_tap_grace / cross.windup, 1.0)
			reach = lerpf(lerpf(19.0, 13.0, prepared), 10.0, charge)
			lean = lerpf(-2.0 * prepared, -4.0, charge)
			twist = lerpf(0.12 * prepared, 0.22, charge)
			glove_color = Color("f6be64").lerp(Color("fff3ae"), charge)
			draw_arc(Vector2.ZERO, 32.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(charge, 0.001), 40, glove_color, 3.0, true)
		AttackState.WINDUP, AttackState.CROSS_PENDING:
			var progress: float = clampf(_attack_elapsed / _attack.windup, 0.0, 1.0)
			reach = lerpf(19.0, 13.0, progress)
			lean = -2.0 * progress
			twist = -0.12 * progress * _attack.glove_side
			if _attack.charge_ratio > 0.0:
				var credit: float = _attack.windup * 0.55
				progress = clampf((_attack_elapsed - credit) / (_attack.windup - credit), 0.0, 1.0)
				var charge: float = _attack.charge_ratio
				reach = lerpf(lerpf(13.0, 10.0, charge), 13.0, progress)
				lean = lerpf(lerpf(-2.0, -4.0, charge), -2.0, progress)
				twist = lerpf(lerpf(0.12, 0.22, charge), 0.12, progress)
			glove_color = Color("f6be64")
		AttackState.ACTIVE:
			reach = _attack.reach
			lean = 3.0
			twist = 0.12 if _attack.glove_side == 1 else -0.28
			glove_color = Color("fff3ae")
		AttackState.RECOVERY:
			if _is_open_to_counter():
				var angle: float = _attack_direction.angle()
				draw_arc(Vector2.ZERO, 28.0, angle - 0.75, angle + 0.75, 16, Color("f6be64"), 3.0, true)
			var progress: float = clampf((_attack_elapsed - _attack.windup - _attack.active) / _attack.recovery, 0.0, 1.0)
			# Vuelve rápido al principio y se acomoda al final.
			var eased: float = 1.0 - pow(1.0 - progress, 3.0)
			reach = lerpf(_attack.reach, 19.0, eased)
			lean = lerpf(3.0, 0.0, eased)
			twist = (0.12 if _attack.glove_side == 1 else -0.28) * (1.0 - eased)
	if is_blocking:
		reach = 22.0
		glove_color = Color("7bafff")
		draw_arc(Vector2.ZERO, 29.0, facing_direction.angle() - 0.9, facing_direction.angle() + 0.9, 24, Color("7bafff"), 5.0, true)
	elif has_guard_break():
		# Arco roto que se vacía al recuperarse; legible también sin sprites.
		var remaining: float = clampf(_guard_break_left / guard_break_duration, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 29.0, -PI * 0.5, -PI * 0.5 + TAU * remaining, 24, Color("ff786d"), 3.0, true)
		glove_color = Color("ff786d")

	# La postura mueve solo el dibujo; el alcance y la colisión son independientes.
	var bob: float = sin(_step_phase * 2.0) * minf(velocity.length() / maxf(walk_speed, 1.0), 1.0)
	var body_center: Vector2 = facing_direction * lean + Vector2(0, bob) + _visual_recoil_offset
	var shoulder_direction: Vector2 = facing_direction.rotated(twist)
	var side: Vector2 = facing_direction.orthogonal() * 11.0 * _attack.glove_side
	var fist: Vector2 = facing_direction * reach + side + _visual_recoil_offset
	var resting_fist: Vector2 = facing_direction * (22.0 if is_blocking else 19.0) - side + _visual_recoil_offset
	var shoulder: Vector2 = shoulder_direction.orthogonal() * 13.0 * _attack.glove_side
	draw_circle(Vector2(0, 6), 22.0, Color(0, 0, 0, 0.3))
	draw_line(body_center + shoulder, fist, Color("318f7a"), 9.0, true)
	draw_line(body_center - shoulder, resting_fist, Color("318f7a"), 9.0, true)
	draw_set_transform(body_center, shoulder_direction.angle(), Vector2(0.85, 1.1))
	var skin: Color = body_color
	if health.current_health <= 0.0:
		skin = Color("687384")
	elif _damage_flash_left > 0.0:
		skin = Color("7bafff") if _last_hit_blocked else Color.WHITE
	draw_circle(Vector2.ZERO, 16.0, skin)
	draw_circle(Vector2(-3, 0), 8.0, Color("b0ead1"))
	draw_set_transform(Vector2.ZERO)
	draw_line(body_center, body_center + shoulder_direction * 19.0, Color("e2fff5"), 2.0)
	# Trazo corto durante el contacto: ayuda a leer la velocidad del guante.
	if attack_state == AttackState.ACTIVE:
		draw_line(facing_direction * 20.0 + side, fist, Color(1.0, 0.85, 0.55, 0.45), 5.0)
	draw_circle(fist, _attack.radius + 1, Color("252638"))
	draw_circle(fist, _attack.radius, glove_color)
	draw_circle(resting_fist, _attack.radius, glove_color if is_blocking else Color("ff786d"))
