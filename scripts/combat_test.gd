extends Node2D

const ViewportLayout = preload("res://scripts/ui/mobile_viewport.gd")
const PauseController = preload("res://scripts/ui/combat_pause.gd")

@export var sparring_enabled: bool = false

@onready var player: CharacterBody2D = $Player
@onready var stamina_bar: ProgressBar = $HUD/Stamina
@onready var dummy: Node2D = $TrainingDummy
@onready var health_bar: ProgressBar = $HUD/DummyHealth
@onready var player_health_bar: ProgressBar = $HUD/PlayerHealth
@onready var feedback: Label = $HUD/Feedback
@onready var touch_controls: Control = $HUD/TouchControls
var ring_rect := Rect2(360, 80, 560, 560)
var _layout_initialized: bool = false
var _fight_finished: bool = false
var _combo_message_left: float = 0.0

func _enter_tree() -> void:
	# Configuración inicial de acciones: también admite botones touch.
	_bind_key("move_left", KEY_A)
	_bind_key("move_left", KEY_LEFT)
	_bind_key("move_right", KEY_D)
	_bind_key("move_right", KEY_RIGHT)
	_bind_key("move_up", KEY_W)
	_bind_key("move_up", KEY_UP)
	_bind_key("move_down", KEY_S)
	_bind_key("move_down", KEY_DOWN)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("punch", KEY_SPACE)
	_bind_key("reset_training", KEY_R)
	_bind_key("cross", KEY_J)
	_bind_key("block", KEY_K)
	_bind_key("dodge", KEY_L)
	_bind_key("pause", KEY_ESCAPE)

func _ready() -> void:
	if sparring_enabled:
		var training_dummy: Node = dummy
		dummy = $Opponent
		player.target = dummy
		training_dummy.free()
		dummy.brain_state_changed.connect(_on_brain_state_changed)
		dummy.stamina_changed.connect(_on_opponent_stamina_changed)
		dummy.punch_swung.connect($ImpactEffects.play_swing)
		dummy.hit_landed.connect($ImpactEffects.play_impact)
		dummy.combo_connected.connect(_on_combo_connected.bind(false))
		dummy.guard_break_changed.connect(_on_guard_break_changed.bind(false))
		_on_opponent_stamina_changed(dummy.stamina, dummy.max_stamina)
		$HUD/Title.text = "SPARRING"
		$HUD/Feedback.text = "El rival entra, combina y sale. Cortale el paso o contraatacá."
	if not sparring_enabled:
		$HUD/Title.text = "PRÁCTICA"
	$HUD/OpponentStaminaLabel.visible = sparring_enabled
	$HUD/OpponentStamina.visible = sparring_enabled
	$HUD/BrainState.visible = sparring_enabled
	$HUD/ModeButton.text = "Practicar con muñeco" if sparring_enabled else "Sparring con rival"
	$HUD/ModeButton.pressed.connect(_switch_mode)
	$HUD/RestartButton.pressed.connect(_restart)
	player.defense_resolved.connect(_on_player_defense)
	player.guard_break_changed.connect(_on_guard_break_changed.bind(true))
	player.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(player.stamina, player.max_stamina)
	player.health.health_changed.connect(_on_player_health_changed)
	player.health.recoverable_changed.connect(_on_player_recoverable_changed)
	_on_player_health_changed(player.health.current_health, player.health.max_health)
	dummy.health.health_changed.connect(_on_dummy_health_changed)
	dummy.health.recoverable_changed.connect(_on_dummy_recoverable_changed)
	_on_dummy_health_changed(dummy.health.current_health, dummy.health.max_health)
	player.punch_finished.connect(_on_punch_finished)
	player.punch_swung.connect($ImpactEffects.play_swing)
	player.hit_landed.connect($ImpactEffects.play_impact)
	player.combo_connected.connect(_on_combo_connected.bind(true))
	touch_controls.movement_changed.connect(player.set_touch_direction)
	touch_controls.jab_requested.connect(player.request_jab)
	touch_controls.dodge_requested.connect(player.request_dodge)
	player.dodge_cooldown_changed.connect(touch_controls.set_dodge_cooldown)
	touch_controls.cross_changed.connect(player.set_touch_cross)
	player.cross_charge_changed.connect(touch_controls.set_cross_charge)
	player.cross_charge_changed.connect(_on_cross_charge_changed)
	touch_controls.block_changed.connect(player.set_touch_block)
	get_viewport().size_changed.connect(_layout_arena)
	_style_fight_hud()
	_on_player_recoverable_changed(player.health.recoverable_health)
	_on_dummy_recoverable_changed(dummy.health.recoverable_health)
	_layout_arena()
	var pause_controller := PauseController.new()
	pause_controller.name = "CombatPause"
	add_child(pause_controller)
	$HUD/Versus.hide()

func _style_fight_hud() -> void:
	# Vida grande y energía fina, con bordes rectos para el futuro arte retro.
	for bar: ProgressBar in [player_health_bar, health_bar, stamina_bar, $HUD/OpponentStamina]:
		bar.show_percentage = false
		var background := StyleBoxFlat.new()
		background.bg_color = Color("17202e")
		background.border_color = Color("516074")
		background.set_border_width_all(2)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("73bfff")
		if bar == player_health_bar:
			fill.bg_color = Color("4fd1b0")
		elif bar == health_bar:
			fill.bg_color = Color("ff9368")
		bar.add_theme_stylebox_override("background", background)
		bar.add_theme_stylebox_override("fill", fill)
	# La reserva amarilla se dibuja detrás de la vida, sobre la misma escala.
	for bar: ProgressBar in [$HUD/PlayerRecoverable, $HUD/DummyRecoverable]:
		var background := StyleBoxFlat.new()
		background.bg_color = Color("17202e")
		background.border_color = Color("516074")
		background.set_border_width_all(2)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("f4ce72")
		bar.add_theme_stylebox_override("background", background)
		bar.add_theme_stylebox_override("fill", fill)
	for bar: ProgressBar in [player_health_bar, health_bar]:
		var transparent := StyleBoxEmpty.new()
		transparent.set_content_margin_all(2.0)
		bar.add_theme_stylebox_override("background", transparent)
	health_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	$HUD/DummyRecoverable.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	$HUD/OpponentStamina.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	$HUD/PlayerHealthLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	$HUD/DummyLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$HUD/OpponentStaminaLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$HUD/PlayerHealthLabel.add_theme_color_override("font_color", Color("8de8cc"))
	$HUD/DummyLabel.add_theme_color_override("font_color", Color("ffb391"))

func _layout_arena() -> void:
	var full_size: Vector2 = get_viewport_rect().size
	var safe_area: Rect2 = ViewportLayout.safe_rect(full_size)
	var viewport_size: Vector2 = safe_area.size
	var arena_top: float = 132.0
	var arena_bottom: float = 80.0
	var usable_height: float = viewport_size.y - arena_top - arena_bottom
	var min_gutter: float = minf(168.0, viewport_size.x * 0.22)
	var side: float = floorf(minf(usable_height, minf(viewport_size.x * 0.46, viewport_size.x - min_gutter * 2.0)))
	ring_rect = Rect2(Vector2((viewport_size.x - side) * 0.5, arena_top + (usable_height - side) * 0.5), Vector2.ONE * side)
	ring_rect.position += safe_area.position
	var center: Vector2 = ring_rect.get_center()
	var side_panel_width: float = maxf(120.0, minf(280.0, ring_rect.position.x - safe_area.position.x - 24.0))
	for control: Control in [$HUD/ModeButton, $HUD/RestartButton]:
		control.size.x = side_panel_width
	$RingWalls/Top.position = Vector2(center.x, ring_rect.position.y - 10)
	$RingWalls/Bottom.position = Vector2(center.x, ring_rect.end.y + 10)
	$RingWalls/Left.position = Vector2(ring_rect.position.x - 10, center.y)
	$RingWalls/Right.position = Vector2(ring_rect.end.x + 10, center.y)
	$RingWalls/Top.shape.size = Vector2(side + 40, 20)
	$RingWalls/Left.shape.size = Vector2(20, side + 40)
	if not _layout_initialized:
		player.position = center - Vector2(side * 0.18, 0)
		dummy.position = center + Vector2(side * 0.18, 0)
		_layout_initialized = true
	else:
		var limits: Rect2 = ring_rect.grow(-25)
		player.position = player.position.clamp(limits.position, limits.end)
		dummy.position = dummy.position.clamp(limits.position, limits.end)
	if sparring_enabled:
		dummy.arena_rect = ring_rect
	_layout_fight_hud(viewport_size)
	for control: Control in [$HUD/HeaderBackground, $HUD/PlayerDefense, $HUD/OpponentDefense, $HUD/PlayerHealthLabel, player_health_bar, $HUD/PlayerRecoverable, $HUD/StaminaLabel, stamina_bar, $HUD/DummyLabel, health_bar, $HUD/DummyRecoverable, $HUD/OpponentStaminaLabel, $HUD/OpponentStamina, $HUD/Title, $HUD/Versus]:
		control.position += safe_area.position
	$HUD/ModeButton.position = Vector2(24.0, 154.0)
	$HUD/RestartButton.position = Vector2(24.0, 209.0)
	$HUD/BrainState.position = Vector2(24.0, 270.0)
	$HUD/BrainState.size.x = side_panel_width
	for control: Control in [$HUD/ModeButton, $HUD/RestartButton, $HUD/BrainState]:
		control.position += safe_area.position
	$HUD/ComboMessage.position = Vector2(ring_rect.position.x - 50, ring_rect.end.y + 8)
	$HUD/ComboMessage.size = Vector2(side + 100, 24)
	$HUD/ComboGuide.position = Vector2(ring_rect.end.x + 28, safe_area.end.y - 180)
	$HUD/ComboGuide.size = Vector2(safe_area.end.x - ring_rect.end.x - 56, 120)
	# En pantallas horizontales bajas se reserva este espacio para los cuatro botones.
	$HUD/ComboGuide.visible = viewport_size.y >= 650.0
	feedback.position = Vector2(ring_rect.position.x - 50, ring_rect.end.y + 33)
	feedback.size = Vector2(side + 100, 20)
	$HUD/Help.position = Vector2(safe_area.position.x, safe_area.end.y - 26)
	$HUD/Help.size = Vector2(viewport_size.x, 24)
	touch_controls.configure_layout(ring_rect, full_size, safe_area)
	queue_redraw()

func release_combat_inputs() -> void:
	touch_controls.release_all()
	player.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	if sparring_enabled:
		dummy.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)

func _layout_fight_hud(viewport_size: Vector2) -> void:
	var margin: float = 36.0
	var center_gap: float = 120.0
	var bar_width: float = (viewport_size.x - margin * 2.0 - center_gap) * 0.5
	var right_x: float = viewport_size.x - margin - bar_width
	var energy_width: float = bar_width * 0.85
	$HUD/HeaderBackground.position = Vector2.ZERO
	$HUD/HeaderBackground.size = Vector2(viewport_size.x, 132)
	$HUD/PlayerDefense.position = Vector2(margin, 112)
	$HUD/PlayerDefense.size = Vector2(bar_width, 18)
	$HUD/OpponentDefense.position = Vector2(right_x, 112)
	$HUD/OpponentDefense.size = Vector2(bar_width, 18)
	$HUD/PlayerHealthLabel.position = Vector2(margin, 14)
	$HUD/PlayerHealthLabel.size = Vector2(bar_width, 24)
	player_health_bar.position = Vector2(margin, 42)
	player_health_bar.size = Vector2(bar_width, 27)
	$HUD/PlayerRecoverable.position = player_health_bar.position
	$HUD/PlayerRecoverable.size = player_health_bar.size
	$HUD/StaminaLabel.position = Vector2(margin, 76)
	$HUD/StaminaLabel.size = Vector2(energy_width, 20)
	stamina_bar.position = Vector2(margin, 99)
	stamina_bar.size = Vector2(energy_width, 11)
	$HUD/DummyLabel.position = Vector2(right_x, 14)
	$HUD/DummyLabel.size = Vector2(bar_width, 24)
	health_bar.position = Vector2(right_x, 42)
	health_bar.size = Vector2(bar_width, 27)
	$HUD/DummyRecoverable.position = health_bar.position
	$HUD/DummyRecoverable.size = health_bar.size
	$HUD/OpponentStaminaLabel.position = Vector2(viewport_size.x - margin - energy_width, 76)
	$HUD/OpponentStaminaLabel.size = Vector2(energy_width, 20)
	$HUD/OpponentStamina.position = Vector2(viewport_size.x - margin - energy_width, 99)
	$HUD/OpponentStamina.size = Vector2(energy_width, 11)
	$HUD/Title.position = Vector2(viewport_size.x * 0.5 - center_gap * 0.5, 16)
	$HUD/Title.size = Vector2(center_gap, 24)
	$HUD/Versus.position = Vector2(viewport_size.x * 0.5 - center_gap * 0.5, 42)
	$HUD/Versus.size = Vector2(center_gap, 48)

func _process(_delta: float) -> void:
	if _combo_message_left > 0.0:
		_combo_message_left = maxf(0.0, _combo_message_left - _delta)
		if _combo_message_left <= 0.0:
			$HUD/ComboMessage.text = ""
	if Input.is_action_just_pressed("reset_training"):
		_restart()

func _on_combo_connected(title: String, bonus_damage: float, _point: Vector2, from_player: bool) -> void:
	if _fight_finished:
		return
	_combo_message_left = 1.2
	$HUD/ComboMessage.text = ("TU COMBO: " if from_player else "RIVAL: ") + title + "  (+%.1f)" % bonus_damage
	$HUD/ComboMessage.modulate = Color("fff3ae") if from_player else Color("ffad91")

func _restart() -> void:
	get_tree().reload_current_scene()

func _switch_mode() -> void:
	var next_scene: String = "res://scenes/combat_test.tscn" if sparring_enabled else "res://scenes/sparring.tscn"
	get_tree().change_scene_to_file(next_scene)

func _on_opponent_stamina_changed(current: float, maximum: float) -> void:
	$HUD/OpponentStamina.max_value = maximum
	$HUD/OpponentStamina.value = current
	$HUD/OpponentStaminaLabel.text = "ENERGÍA  %.0f / %.0f" % [current, maximum]

func _on_brain_state_changed(label: String) -> void:
	$HUD/BrainState.text = "RIVAL: " + label

func _on_player_defense(blocked: bool, guard_broken: bool) -> void:
	if _fight_finished:
		return
	if guard_broken:
		feedback.text = "¡Guardia rota! Retrocedé; estás expuesto un instante."
	elif blocked:
		feedback.text = "Bloqueaste el golpe: menos daño, con coste de estamina."
	else:
		feedback.text = "¡Te conectaron! Probá salir de distancia o usar BLOCK."

func _on_guard_break_changed(broken: bool, from_player: bool) -> void:
	var label: Label = $HUD/PlayerDefense if from_player else $HUD/OpponentDefense
	label.text = "GUARDIA ROTA" if broken else ""

func _finish_fight(player_won: bool) -> void:
	if _fight_finished:
		return
	_fight_finished = true
	player.combat_enabled = false
	player.health.recovery_active = false
	player.stop_combat()
	dummy.combat_enabled = false
	dummy.health.recovery_active = false
	dummy.stop_combat()
	touch_controls.release_all()
	feedback.text = ("¡Ganaste el sparring!" if player_won else "Fin del sparring: perdiste.") + " Reiniciá para volver a pelear."

func _on_dummy_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	$HUD/DummyLabel.text = ("RIVAL" if sparring_enabled else "MUÑECO") + "  %.0f / %.0f" % [current, maximum]
	_on_dummy_recoverable_changed(dummy.health.recoverable_health)
	if current <= 0.0:
		if sparring_enabled:
			_finish_fight(true)
		else:
			feedback.text = "Muñeco derrotado. Presioná R para reiniciar."

func _on_player_health_changed(current: float, maximum: float) -> void:
	player_health_bar.max_value = maximum
	player_health_bar.value = current
	$HUD/PlayerHealthLabel.text = "JUGADOR  %.0f / %.0f" % [current, maximum]
	_on_player_recoverable_changed(player.health.recoverable_health)
	if current <= 0.0 and sparring_enabled:
		_finish_fight(false)

func _on_player_recoverable_changed(amount: float) -> void:
	$HUD/PlayerRecoverable.max_value = player.health.max_health
	$HUD/PlayerRecoverable.value = player.health.current_health + amount
	$HUD/PlayerHealthLabel.text = "JUGADOR  %.0f / %.0f" % [player.health.current_health, player.health.max_health]
	if amount >= 0.5:
		$HUD/PlayerHealthLabel.text += "  [+%.0f]" % amount

func _on_dummy_recoverable_changed(amount: float) -> void:
	$HUD/DummyRecoverable.max_value = dummy.health.max_health
	$HUD/DummyRecoverable.value = dummy.health.current_health + amount
	$HUD/DummyLabel.text = ("RIVAL" if sparring_enabled else "MUÑECO") + "  %.0f / %.0f" % [dummy.health.current_health, dummy.health.max_health]
	if amount >= 0.5:
		$HUD/DummyLabel.text += "  [+%.0f]" % amount

func _on_punch_finished(connected: bool) -> void:
	if _fight_finished or dummy.health.current_health <= 0.0:
		return
	feedback.text = "¡Golpe conectado!" if connected else "Fuera de alcance: acercate un poco más."

func _on_cross_charge_changed(ratio: float, charging: bool) -> void:
	if _fight_finished or dummy.health.current_health <= 0.0:
		return
	if charging:
		var damage: float = player.cross.damage * lerpf(1.0, player.max_charge_damage_scale, ratio)
		var cost: float = player.cross.stamina_cost * lerpf(1.0, player.max_charge_cost_scale, ratio)
		feedback.text = "CROSS %d%% · Daño %.0f · Energía %.0f" % [roundi(ratio * 100.0), damage, cost]
	else:
		feedback.text = "CROSS: tocá para un recto o mantené para cargar y soltá."

func _bind_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	$HUD/StaminaLabel.text = "ENERGÍA  %.0f / %.0f" % [current, maximum]

func _draw() -> void:
	draw_rect(ring_rect, Color("21344a"))
	for margin: float in [0.0, 7.0, 14.0]:
		draw_rect(ring_rect.grow(margin + 3), Color("9baabd"), false, 2.0)
