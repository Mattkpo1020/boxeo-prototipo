extends SceneTree

var _failures: int = 0

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

func _touch(index: int, position_on_screen: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position_on_screen
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)

func _run() -> void:
	var scene: Node = load("res://scenes/combat_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	var player = scene.get_node("Player")
	# Escenario acotado para comprobar costes y daño independientemente del balance.
	player.max_stamina = 100.0
	player.stamina = 100.0
	var training_health: HealthComponent = scene.get_node("TrainingDummy/Health")
	training_health.max_health = 100.0
	training_health.reset()
	var controls = scene.get_node("HUD/TouchControls")
	var dummy = scene.get_node("TrainingDummy")
	player.stamina_regen = 0.0

	# Comprueba el diseño en varios formatos horizontales, incluido 20:9.
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(960, 720)]:
		root.size = resolution
		root.content_scale_size = resolution
		await _frames(3)
		var ring: Rect2 = scene.ring_rect
		_expect(is_equal_approx(ring.size.x, ring.size.y), "El ring debe conservar su forma cuadrada.")
		_expect(ring.position.y - 18.0 >= scene.get_node("HUD/HeaderBackground").get_rect().end.y, "Las cuerdas superiores deben quedar debajo del encabezado.")
		_expect(controls.joystick_center.x + controls.joystick_radius < ring.position.x, "El joystick debe quedar fuera del ring.")
		for center: Vector2 in controls.button_centers.values():
			_expect(center.x - controls.button_radius > ring.end.x, "Los botones deben quedar fuera del ring.")
		_expect(controls.button_centers[&"cross"].x < controls.button_centers[&"jab"].x and controls.button_centers[&"block"].x < controls.button_centers[&"dodge"].x, "CROSS y BLOCK deben quedar a la izquierda del grupo.")
		_expect(controls.button_centers[&"cross"].distance_to(controls.button_centers[&"jab"]) > controls.button_radius * 2.2, "Las áreas táctiles deben quedar separadas.")
		_expect(ring.has_point(player.position) and ring.has_point(dummy.position), "Los personajes deben seguir dentro del ring al redimensionar.")

	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await _frames(3)
	var start: Vector2 = player.position
	_touch(0, controls.joystick_center + Vector2(controls.joystick_radius * 0.8, 0), true)
	_touch(1, controls.button_centers[&"jab"], true)
	await _frames(4)
	_expect(player.position.x > start.x, "El joystick debe mover al jugador mientras golpea.")
	_expect(is_equal_approx(player.stamina, 92.0), "El segundo dedo debe iniciar un único jab.")
	_touch(1, controls.button_centers[&"jab"], false)
	await _frames(2)
	_expect(player.velocity.x > 0.0, "Soltar el jab no debe soltar el joystick.")
	_touch(0, controls.joystick_center, false)
	await _frames(30)
	_expect(player.velocity.is_zero_approx(), "Soltar el joystick debe detener el movimiento.")

	_touch(2, controls.button_centers[&"block"], true)
	await _frames(2)
	_expect(player.is_blocking, "BLOCK debe mantener la guardia.")
	_touch(3, controls.button_centers[&"jab"], true)
	_touch(3, controls.button_centers[&"jab"], false)
	await _frames(2)
	_expect(is_equal_approx(player.stamina, 92.0), "No debe atacar mientras mantiene la guardia.")
	_touch(2, controls.button_centers[&"block"], false, true)
	await _frames(2)
	_expect(not player.is_blocking, "Una pulsación cancelada debe soltar la guardia.")

	player.position = dummy.position - Vector2(60, 0)
	await _frames(3)
	var cross_edge: Vector2 = controls.button_centers[&"cross"] + Vector2.RIGHT * controls.button_radius * 1.07
	_touch(4, cross_edge, true)
	_touch(4, cross_edge, false)
	await _frames(42)
	_expect(is_equal_approx(player.stamina, 70.0), "CROSS debe consumir 22 de estamina.")
	_expect(is_equal_approx(dummy.health.current_health, 82.0), "CROSS debe hacer 18 de daño una sola vez.")

	_touch(0, controls.joystick_center + Vector2(50, 0), true)
	_touch(2, controls.button_centers[&"block"], true)
	await _frames(2)
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	_expect(player.velocity.is_zero_approx() and not player.is_blocking, "Al perder foco no deben quedar controles pulsados.")
	scene.queue_free()
	await process_frame
	print("MOBILE_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
