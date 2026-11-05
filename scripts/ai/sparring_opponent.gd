extends "res://scripts/fighters/fighter_body.gd"

const OpponentStyle = preload("res://scripts/ai/opponent_style.gd")

signal brain_state_changed(label: String)

enum BrainState { APPROACH, MEASURE, TELEGRAPH, RECOVER, RETREAT, REST, STOPPED, COMBO, GUARD, DODGE }
const ROPE_MARGIN: float = 22.0
const FOOTWORK_LOOKAHEAD: float = 32.0
@export var brain_enabled: bool = true
@export_range(0.05, 0.5) var decision_interval: float = 0.10
@export_range(0.06, 0.8) var telegraph_duration: float = 0.11
@export var attack_distance: float = 67.0
@export var neutral_distance: float = 104.0
@export_range(0.0, 1.0) var guard_probability: float = 0.68
@export_range(0.0, 1.0) var dodge_probability: float = 0.25
@export_range(0.0, 1.0) var proactive_guard_probability: float = 0.06
@export var reaction_min: float = 0.10
@export var reaction_max: float = 0.18
@export var arena_rect := Rect2(360, 80, 560, 560)

var brain_state: BrainState = BrainState.STOPPED
var _decision_left: float = 0.0
var _cooldown_left: float = 0.3
var _telegraph_left: float = 0.0
var _resting: bool = false
var _circle_side: float = 1.0
var _random := RandomNumberGenerator.new()
var _retreat_left: float = 0.0
var _guard_hold_left: float = 0.0
var _guard_reaction_left: float = 0.0
var _guard_response_pending: bool = false
var _prefer_dodge: bool = false
var _observed_attack_state: int = -1
var _circle_change_left: float = 1.0
var _spacing_goal: float = 96.0
var _combo: Array[BoxingAttack] = []
var _combo_next: int = 0
var _combo_active: bool = false
var _combo_step_queued: bool = false
var style: int = OpponentStyle.Style.PRESSURE
var _circle_effort: float = 0.45
var _retreat_scale: float = 1.0
var _counter_pending: bool = false

func _ready() -> void:
	super._ready()
	_random.randomize()
	style = OpponentStyle.selected
	match style:
		OpponentStyle.Style.COUNTER:
			guard_probability = 0.84
			dodge_probability = 0.12
			neutral_distance = 112.0
			_retreat_scale = 1.15
		OpponentStyle.Style.MOBILITY:
			guard_probability = 0.76
			dodge_probability = 0.58
			neutral_distance = 120.0
			_circle_effort = 0.7
			_retreat_scale = 1.15
	_spacing_goal = neutral_distance
	punch_started.connect(_on_own_punch_started)
	defense_resolved.connect(_on_defense_resolved)

func stop_combat() -> void:
	super.stop_combat()
	_combo.clear()
	_combo_active = false
	_combo_step_queued = false
	_combo_next = 0
	_guard_hold_left = 0.0
	_guard_response_pending = false
	_prefer_dodge = false
	_counter_pending = false
	_retreat_left = 0.0
	_set_brain_state(BrainState.STOPPED)

func _physics_process(delta: float) -> void:
	if not brain_enabled:
		set_touch_direction(Vector2.ZERO)
	elif not can_fight() or not is_instance_valid(target) or not target.has_method("can_fight") or not target.can_fight():
		stop_combat()
	elif not is_hit_paused():
		_update_timers(delta)
		_observe_visible_attack(delta)
		var offset: Vector2 = target.global_position - global_position
		var distance: float = offset.length()
		var toward: Vector2 = offset.normalized()
		if has_guard_break():
			set_touch_block(false)
			_set_brain_state(BrainState.REST)
			set_touch_direction(_safe_direction(-toward + toward.orthogonal() * _circle_side * 0.35))
		elif is_dodge_busy():
			set_touch_direction(Vector2.ZERO)
			_set_brain_state(BrainState.DODGE)
		elif _combo_active or attack_state != AttackState.IDLE:
			_update_combo(toward, distance)
		elif _guard_hold_left > 0.0 and stamina >= jab.stamina_cost and not has_guard_break():
			_hold_guard(toward, distance)
		elif brain_state == BrainState.TELEGRAPH:
			_update_telegraph(delta, toward, distance)
		elif _decision_left <= 0.0:
			_decision_left = decision_interval
			_think()
	super._physics_process(delta)

func _update_timers(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_retreat_left = maxf(0.0, _retreat_left - delta)
	_guard_hold_left = maxf(0.0, _guard_hold_left - delta)
	_decision_left -= delta
	_circle_change_left -= delta
	if _circle_change_left <= 0.0:
		_circle_change_left = _random.randf_range(0.7, 1.5)
		if _random.randf() < 0.45:
			_circle_side *= -1.0

# Observa poses visibles del rival y tarda en responder. Nunca lee botones.
# El jab puede llegar antes que la reacción; el cross y la carga son más legibles.
func _observe_visible_attack(delta: float) -> void:
	var seen_state: int = target.attack_state
	# Tap, windup y carga son el mismo aviso visible; no reinicia la reacción al confirmar carga.
	if seen_state == AttackState.CROSS_PENDING or seen_state == AttackState.CHARGING:
		seen_state = AttackState.WINDUP
	if seen_state != _observed_attack_state:
		_observed_attack_state = seen_state
		_counter_pending = false
		if style == OpponentStyle.Style.COUNTER and seen_state == AttackState.RECOVERY:
			var boxer := target as FighterBody
			_counter_pending = boxer != null and boxer._is_open_to_counter() and _random.randf() < 0.65
		if seen_state == AttackState.WINDUP:
			if global_position.distance_to(target.global_position) < 105.0 and _random.randf() < guard_probability:
				_guard_response_pending = true
				_guard_reaction_left = _random.randf_range(reaction_min, reaction_max)
				_prefer_dodge = target.attack_state != AttackState.CHARGING and _random.randf() < dodge_probability
	if _guard_response_pending:
		_guard_reaction_left -= delta
		if _guard_reaction_left <= 0.0:
			_guard_response_pending = false
			if _prefer_dodge and _try_reactive_dodge(target.attack_state):
				return
			_guard_hold_left = maxf(_guard_hold_left, _random.randf_range(0.22, 0.38))

func _try_reactive_dodge(seen_state: int) -> bool:
	if seen_state != AttackState.WINDUP and seen_state != AttackState.ACTIVE:
		return false
	if attack_state != AttackState.IDLE or _combo_active or has_guard_break():
		return false
	if stamina < dodge_cost + jab.stamina_cost or get_dodge_cooldown_remaining() > 0.0:
		return false
	if global_position.distance_to(target.global_position) >= 105.0:
		return false
	var toward: Vector2 = global_position.direction_to(target.global_position)
	var movement: Vector2 = _safe_direction(-toward + toward.orthogonal() * _circle_side * 0.65)
	if movement.is_zero_approx():
		return false
	set_touch_direction(movement)
	if not request_dodge():
		return false
	set_touch_block(false)
	_guard_hold_left = 0.0
	_decision_left = 0.0
	return true

func _hold_guard(toward: Vector2, distance: float) -> void:
	set_touch_block(true)
	_set_brain_state(BrainState.GUARD)
	var movement: Vector2 = toward.orthogonal() * _circle_side * 0.18
	if distance < 48.0:
		movement -= toward * 0.6
	set_touch_direction(_safe_direction(movement))
	_decision_left = 0.0

func _think() -> void:
	var offset: Vector2 = target.global_position - global_position
	var distance: float = offset.length()
	var toward: Vector2 = offset.normalized()
	set_touch_block(false)
	if stamina < max_stamina * 0.15:
		_resting = true
	if _resting and stamina >= max_stamina * 0.4:
		_resting = false
	if _resting:
		_set_brain_state(BrainState.REST)
		var movement: Vector2 = toward.orthogonal() * _circle_side * 0.35
		if distance < neutral_distance + 20.0:
			movement -= toward * 0.9
		set_touch_direction(_safe_direction(movement.limit_length(1.0)))
		return

	if _counter_pending and distance <= attack_distance:
		_counter_pending = false
		if _request_attack(jab):
			set_touch_direction(Vector2.ZERO)
			_finish_combo()
			return

	# Después de cada ráfaga sale de alcance y cambia de ángulo.
	if _retreat_left > 0.0 or (_cooldown_left > 0.0 and distance < _spacing_goal - 10.0) or distance < 46.0:
		_set_brain_state(BrainState.RETREAT)
		var movement: Vector2 = toward.orthogonal() * _circle_side * 0.45
		if distance < _spacing_goal:
			movement -= toward
		set_touch_direction(_safe_direction(movement.limit_length(1.0)))
		return

	if distance < 82.0 and _random.randf() < proactive_guard_probability:
		_guard_hold_left = _random.randf_range(0.16, 0.28)
		_hold_guard(toward, distance)
		return

	if _cooldown_left > 0.0:
		_set_brain_state(BrainState.MEASURE)
		var spacing: float = clampf((distance - _spacing_goal) / 50.0, -0.45, 0.45)
		set_touch_direction(_safe_direction((toward * spacing + toward.orthogonal() * _circle_side * _circle_effort).limit_length(1.0)))
	elif distance > attack_distance:
		_set_brain_state(BrainState.APPROACH)
		var strength: float = clampf((distance - (attack_distance - 6.0)) / 26.0, 0.25, 1.0)
		set_touch_direction(_safe_direction((toward * strength + toward.orthogonal() * _circle_side * 0.12).limit_length(1.0)))
	else:
		_set_brain_state(BrainState.TELEGRAPH)
		_telegraph_left = telegraph_duration * _random.randf_range(0.8, 1.2)
		set_touch_direction(Vector2.ZERO)

func _update_telegraph(delta: float, toward: Vector2, distance: float) -> void:
	set_touch_block(false)
	_telegraph_left -= delta
	if distance > attack_distance + 10.0 or distance < 43.0:
		_set_brain_state(BrainState.MEASURE)
		_decision_left = 0.0
		return
	set_touch_direction(_safe_direction(toward * 0.12) if distance > attack_distance - 3.0 else Vector2.ZERO)
	if _telegraph_left <= 0.0:
		_plan_combo()
		if not _request_attack(_combo[0]):
			_finish_combo()

func _plan_combo() -> void:
	_combo.clear()
	var roll: float = _random.randf()
	if style == OpponentStyle.Style.MOBILITY:
		_combo.append(jab)
		if roll < 0.5:
			_combo.append(cross)
	elif roll < 0.45:
		_combo.assign([jab, cross])
	elif roll < 0.75:
		_combo.assign([jab, jab, cross])
	elif roll < 0.9:
		_combo.assign([jab, jab])
	else:
		_combo.assign([cross, jab])
	# Las ráfagas usan recursos reales y se recortan si falta energía.
	var budget: float = stamina
	var affordable: int = 0
	for attack: BoxingAttack in _combo:
		if budget < attack.stamina_cost:
			break
		budget -= attack.stamina_cost
		affordable += 1
	_combo.resize(affordable)
	if _combo.is_empty():
		_combo.append(jab)
	_combo_next = 0
	_combo_active = true
	_combo_step_queued = false
	_set_brain_state(BrainState.COMBO)

func _on_own_punch_started(_direction: Vector2) -> void:
	if _combo_active:
		_combo_next += 1
		_combo_step_queued = false

func _update_combo(toward: Vector2, distance: float) -> void:
	set_touch_block(false)
	_set_brain_state(BrainState.COMBO if _combo_active else BrainState.RECOVER)
	# Ajustes pequeños de pies; nunca persigue indefinidamente golpeando.
	var advance: float = clampf((distance - (attack_distance - 5.0)) / 30.0, -0.4, 0.45)
	set_touch_direction(_safe_direction((toward * advance + toward.orthogonal() * _circle_side * 0.08).limit_length(0.6)))
	if attack_state == AttackState.IDLE:
		_finish_combo()
		return
	if not _combo_active or _combo_next >= _combo.size() or _combo_step_queued:
		return
	var next_attack: BoxingAttack = _combo[_combo_next]
	if distance > attack_distance + 13.0 or stamina < next_attack.stamina_cost:
		_combo_active = false
		clear_queued_attack()
		return
	# Usa la misma cola de una pulsación que el jugador, sin cancelar contacto.
	if attack_state == AttackState.RECOVERY:
		if remaining_recovery(next_attack) <= input_buffer_window - 0.02:
			_combo_step_queued = _request_attack(next_attack)

func _finish_combo() -> void:
	_combo_active = false
	_combo.clear()
	_combo_step_queued = false
	_combo_next = 0
	_spacing_goal = _random.randf_range(neutral_distance - 6.0, neutral_distance + 18.0)
	_retreat_left = _random.randf_range(0.35, 0.65) * _retreat_scale
	_cooldown_left = _retreat_left + _random.randf_range(0.10, 0.35)
	_circle_side *= -1.0
	_decision_left = 0.0
	_set_brain_state(BrainState.RETREAT)

func _on_defense_resolved(blocked: bool, guard_broken: bool) -> void:
	if not brain_enabled:
		return
	if blocked:
		# Tras cubrirse puede tomar la iniciativa, conservando su recuperación.
		_cooldown_left = minf(_cooldown_left, 0.12)
	elif guard_broken:
		_combo.clear()
		_combo_active = false
		_combo_step_queued = false
		_guard_hold_left = 0.0
		_guard_response_pending = false
		_resting = true
		_decision_left = 0.0
	elif not guard_broken:
		_guard_response_pending = true
		_prefer_dodge = false
		_guard_reaction_left = _random.randf_range(reaction_min, reaction_max)
		if _combo_active and _random.randf() < 0.4:
			_combo_active = false
			clear_queued_attack()

func _clip_direction(wanted: Vector2) -> Vector2:
	var limits: Rect2 = arena_rect.grow(-ROPE_MARGIN)
	var projected: Vector2 = global_position + wanted * FOOTWORK_LOOKAHEAD
	var result: Vector2 = wanted
	# Solo frena el movimiento hacia la cuerda. Desde el borde se puede volver
	# hacia adentro incluso si este paso todavía no alcanza el margen.
	if (wanted.x < 0.0 and projected.x < limits.position.x) or (wanted.x > 0.0 and projected.x > limits.end.x):
		result.x = 0.0
	if (wanted.y < 0.0 and projected.y < limits.position.y) or (wanted.y > 0.0 and projected.y > limits.end.y):
		result.y = 0.0
	return result

func _safe_direction(wanted: Vector2) -> Vector2:
	var result: Vector2 = _clip_direction(wanted)
	if wanted.is_zero_approx() or not is_instance_valid(target):
		return result.limit_length(1.0)
	var toward: Vector2 = global_position.direction_to(target.global_position)
	var retreat_blocked: bool = wanted.dot(toward) < 0.0 and result.length_squared() < wanted.length_squared() * 0.5
	if result.is_zero_approx() or retreat_blocked:
		result = _rope_exit_direction(result, toward, wanted.length())
	return result.limit_length(1.0)

func _rope_exit_direction(clipped: Vector2, toward: Vector2, effort: float) -> Vector2:
	var lateral: Vector2 = toward.orthogonal() * _circle_side * minf(effort, 1.0)
	var best := Vector2.ZERO
	var best_score: float = -INF
	for candidate: Vector2 in [clipped, _clip_direction(lateral), _clip_direction(-lateral)]:
		if candidate.is_zero_approx():
			continue
		var end: Vector2 = global_position + candidate * FOOTWORK_LOOKAHEAD
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(target.global_position, global_position, end)
		# Prefiere una ruta que mantenga distancia durante todo el paso.
		# Si ambas son seguras, elige la que termina más lejos del rival.
		var score: float = nearest.distance_to(target.global_position) * 2.0 + end.distance_to(target.global_position)
		if score > best_score:
			best = candidate
			best_score = score
	return best

func get_brain_label() -> String:
	match brain_state:
		BrainState.APPROACH: return "ENTRA A DISTANCIA"
		BrainState.MEASURE: return "CIRCULA Y MIDE"
		BrainState.TELEGRAPH: return "PREPARA ATAQUE"
		BrainState.RECOVER: return "SE RECUPERA"
		BrainState.RETREAT: return "SALE Y CAMBIA ÁNGULO"
		BrainState.REST: return "DESCANSA"
		BrainState.COMBO: return "COMBINACIÓN"
		BrainState.GUARD: return "SE CUBRE"
		BrainState.DODGE: return "ESQUIVA"
	return "DETENIDO"

func _set_brain_state(next: BrainState) -> void:
	if brain_state == next:
		return
	brain_state = next
	brain_state_changed.emit(get_brain_label())
	queue_redraw()

func _draw() -> void:
	super._draw()
	if brain_state == BrainState.TELEGRAPH and can_fight():
		draw_arc(Vector2.ZERO, 27.0, -PI * 0.5, PI * 1.5, 32, Color("f6be64"), 3.0, true)
