extends SceneTree

var _failures: int = 0
var _swings: Array[int] = []
var _charge_displays: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame

func _touch(position_on_screen: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 1
	event.position = position_on_screen
	event.pressed = pressed
	Input.parse_input_event(event)

func _idle(player: Node) -> void:
	for index in 120:
		if player.attack_state == player.AttackState.IDLE:
			return
		await _frames(1)
	_expect(false, "El recto debe finalizar.")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene: Node = load("res://scenes/combat_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	var player = scene.get_node("Player")
	var dummy = scene.get_node("TrainingDummy")
	var controls = scene.get_node("HUD/TouchControls")
	var button: Vector2 = controls.button_centers[&"cross"]
	player.stamina_regen = 0.0
	player.position = dummy.position - Vector2(150, 0)
	player.punch_swung.connect(func(_attack: BoxingAttack): _swings.append(Engine.get_physics_frames()))
	player.cross_charge_changed.connect(func(_ratio: float, active: bool):
		if active: _charge_displays += 1
	)
	var press_frame: int = Engine.get_physics_frames()
	player.request_cross()
	for index in 30:
		if not _swings.is_empty(): break
		await _frames(1)
	var direct_delay: int = _swings[0] - press_frame
	await _idle(player)
	var tap_delays: Array[int] = []

	# Taps de 17, 67 y 133 ms deben compartir el tiempo de preparación.
	for held_frames in [1, 4, 8]:
		player.stamina = 300.0
		_swings.clear()
		_charge_displays = 0
		press_frame = Engine.get_physics_frames()
		_touch(button, true)
		await _frames(held_frames)
		var prepared: float = player._attack_elapsed
		_expect(player.attack_state == player.AttackState.CROSS_PENDING and not controls._charging, "Un tap debe mostrar preparación normal, sin postura ni indicador de carga.")
		_touch(button, false)
		await _frames(1)
		_expect(player._attack_elapsed >= prepared, "Soltar no debe reiniciar la animación ya preparada.")
		for index in 30:
			if not _swings.is_empty(): break
			await _frames(1)
		_expect(_swings.size() == 1, "Cada tap debe lanzar un único cross.")
		if not _swings.is_empty():
			var delay: int = _swings[0] - press_frame
			tap_delays.append(delay)
			_expect(delay <= direct_delay + 2, "La duración del tap no debe sumarse a toda la preparación del recto.")
		_expect(_charge_displays == 0 and is_equal_approx(player.stamina, 278.0), "El tap debe conservar coste normal y no emitir carga visual.")
		await _idle(player)

	_expect(tap_delays.max() - tap_delays.min() <= 2, "Los taps breves deben responder con una cadencia consistente.")

	# Una pulsación que cruza el fin del jab no debe hacer un amago de carga.
	player.stamina = 300.0
	_swings.clear()
	_charge_displays = 0
	player.request_jab()
	for index in 60:
		if player.attack_state == player.AttackState.RECOVERY and player._get_recovery_end(player.cross) - player._attack_elapsed <= 0.035:
			break
		await _frames(1)
	_touch(button, true)
	await _frames(4)
	_expect(player.attack_state != player.AttackState.CHARGING and not controls._charging, "Encadenar con el botón todavía pulsado no debe activar una carga accidental.")
	_touch(button, false)
	await _frames(3)
	await _idle(player)
	_expect(_swings.size() == 2 and _charge_displays == 0 and is_equal_approx(player.stamina, 270.0), "El combo con tap debe lanzar jab y cross normales sin carga visual.")

	# Mantener sí confirma la carga, que sale desde una preparación avanzada.
	player.stamina = 300.0
	_swings.clear()
	_touch(button, true)
	await _frames(30)
	_expect(player.attack_state == player.AttackState.CHARGING and controls._charging, "Mantener debe activar la carga después del umbral.")
	var release_frame: int = Engine.get_physics_frames()
	_touch(button, false)
	for index in 20:
		if not _swings.is_empty(): break
		await _frames(1)
	_expect(_swings.size() == 1 and _swings[0] - release_frame <= 8, "El cross cargado debe salir sin repetir una preparación completa al soltar.")
	await _idle(player)
	print("CROSS RESPONSE (frames): direct=", direct_delay, " taps=", tap_delays)
	scene.queue_free()
	await process_frame
	print("CROSS_RESPONSE_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
