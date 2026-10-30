extends SceneTree

var _failures: int = 0
var _starts: Array[Dictionary] = []
var _blocks: int = 0

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

func _run() -> void:
	var scene: Node = load("res://scenes/sparring.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	var player = scene.get_node("Player")
	var opponent = scene.get_node("Opponent")
	opponent._random.seed = 1234
	# Reservas amplias para observar varias ráfagas sin finalizar el encuentro.
	player.health.max_health = 2000.0
	player.health.reset()
	opponent.punch_started.connect(func(_direction: Vector2):
		_starts.append({"frame": Engine.get_physics_frames(), "hand": opponent._attack.glove_side, "cost": opponent._attack.stamina_cost, "stamina": opponent.stamina})
	)
	opponent.defense_resolved.connect(func(blocked: bool, _broken: bool):
		if blocked: _blocks += 1
	)
	var separated: bool = false
	var lateral_motion: bool = false
	var saw_retreat: bool = false
	var initial_y: float = opponent.position.y
	for index in 96:
		await _frames(10)
		var distance: float = player.position.distance_to(opponent.position)
		if _starts.size() > 0 and distance >= 85.0:
			separated = true
		if absf(opponent.position.y - initial_y) > 12.0:
			lateral_motion = true
		if opponent.brain_state == opponent.BrainState.RETREAT:
			saw_retreat = true
		_expect(scene.ring_rect.grow(-16.0).has_point(opponent.position), "El rival debe mantenerse dentro de las paredes.")
	_expect(_starts.size() >= 6, "El rival debe producir varias ráfagas en 16 segundos.")
	var used_cross: bool = false
	var quick_follow_up: bool = false
	var switched_hands: bool = false
	for index in _starts.size():
		used_cross = used_cross or _starts[index]["hand"] == -1
		_expect(_starts[index]["stamina"] >= 0.0, "Las combinaciones no deben producir estamina negativa.")
		if index > 0:
			var interval: float = float(_starts[index]["frame"] - _starts[index - 1]["frame"]) / Engine.physics_ticks_per_second
			quick_follow_up = quick_follow_up or interval < 0.4
			switched_hands = switched_hands or (_starts[index]["hand"] != _starts[index - 1]["hand"] and interval < 0.8)
	_expect(used_cross and quick_follow_up and switched_hands, "Debe combinar ambas manos con seguimientos rápidos.")
	_expect(separated and saw_retreat, "Después de atacar debe salir claramente del alcance de golpe.")
	_expect(lateral_motion, "Debe cambiar de ángulo en lugar de seguir una línea recta.")

	# Prueba controlada: reacción a un cross visible, sin ataques propios.
	opponent.stop_combat()
	player.stop_combat()
	opponent.walk_speed = 0.0 # Aísla el bloqueo de una posible evasión por distancia.
	player.position = scene.ring_rect.get_center() - Vector2(28, 0)
	opponent.position = scene.ring_rect.get_center() + Vector2(28, 0)
	opponent._cooldown_left = 999.0
	opponent._decision_left = 0.0
	opponent._retreat_left = 0.0
	opponent._observed_attack_state = -1
	opponent.guard_probability = 1.0
	opponent.proactive_guard_probability = 0.0
	opponent.reaction_min = 0.08
	opponent.reaction_max = 0.08
	opponent.stamina = 300.0
	opponent.health.reset()
	opponent._guard_hold_left = 0.0
	await _frames(2)
	player.stamina = 300.0
	var before: int = _blocks
	_expect(player.request_cross(), "Debe iniciar el cross de prueba.")
	await _frames(2)
	_expect(not opponent.is_blocking, "La defensa no debe activarse instantáneamente al iniciar el ataque.")
	await _frames(20)
	_expect(_blocks > before, "Tras su tiempo de reacción debe bloquear un cross frontal.")
	_expect(opponent.health.current_health >= 495.5, "El bloqueo debe reducir el daño real recibido.")
	await _frames(45)

	# Con probabilidad cero no obtiene un bloqueo automático perfecto.
	opponent.stop_combat()
	player.stop_combat()
	opponent._cooldown_left = 999.0
	opponent.guard_probability = 0.0
	opponent._observed_attack_state = -1
	opponent.position = scene.ring_rect.get_center() + Vector2(28, 0)
	player.position = scene.ring_rect.get_center() - Vector2(28, 0)
	opponent.health.reset()
	# Mantener la distancia en esta prueba aísla la decisión de guardia.
	opponent.walk_speed = 0.0
	before = _blocks
	player.request_cross()
	await _frames(45)
	_expect(_blocks == before and is_equal_approx(opponent.health.current_health, 482.0), "La probabilidad de guardia debe permitir golpes sin bloquear.")

	# Una esquina no debe dejarlo empujando siempre las paredes.
	opponent.stop_combat()
	opponent.walk_speed = 145.0
	opponent.position = scene.ring_rect.position + Vector2(24, 24)
	player.position = opponent.position + Vector2(44, 44)
	opponent._cooldown_left = 1.0
	opponent._retreat_left = 0.7
	opponent._spacing_goal = 110.0
	opponent._decision_left = 0.0
	var corner_position: Vector2 = opponent.position
	await _frames(30)
	_expect(opponent.position.distance_to(corner_position) > 15.0, "Debe buscar una salida lateral cuando queda en una esquina.")
	_expect(scene.ring_rect.grow(-16).has_point(opponent.position), "Salir de una esquina debe respetar las colisiones.")
	print("OPPONENT SAMPLE: attacks=", _starts.size(), " cross=", used_cross, " separated=", separated, " lateral=", lateral_motion, " blocks=", _blocks)
	scene.queue_free()
	await process_frame
	print("OPPONENT_BEHAVIOR_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
