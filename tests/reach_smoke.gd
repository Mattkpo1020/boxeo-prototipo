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

func _run() -> void:
	# Este escenario aislado no carga la arena que registra los controles.
	for action in ["move_left", "move_right", "move_up", "move_down", "sprint", "punch", "cross", "block", "dodge"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var stage := Node2D.new()
	root.add_child(stage)
	var player = load("res://scenes/player.tscn").instantiate()
	var dummy = load("res://scenes/training_dummy.tscn").instantiate()
	stage.add_child(player)
	stage.add_child(dummy)
	player.position = Vector2(400, 400)
	player.stamina_regen = 0.0
	player.attack_collision_mask = 6
	player._hit_query.collision_mask = 6 # Incluye su propia hurtbox para comprobar la exclusión.
	# Sin autoorientación: comprueba también que un golpe frontal no alcance
	# objetivos laterales o detrás del boxeador.
	player.target = null
	for hand in ["jab", "cross"]:
		var damage: float = player.jab.damage if hand == "jab" else player.cross.damage
		var extended_distance: float = 80.0 if hand == "jab" else 76.0
		var miss_distance: float = 85.0 if hand == "jab" else 82.0
		for angle in [0.0, PI * 0.5, PI * 0.25, PI]:
			var direction := Vector2.RIGHT.rotated(angle)
			for distance in [38.0, 50.0, extended_distance, miss_distance]:
				player.stop_combat()
				player.stamina = player.max_stamina
				player.facing_direction = direction
				dummy.position = player.position + direction * distance
				dummy.health.reset()
				await _frames(2)
				var accepted: bool = player.request_jab() if hand == "jab" else player.request_cross()
				_expect(accepted, "Debe aceptar el golpe de prueba.")
				await _frames(50)
				var expected: float = dummy.health.max_health - (damage if distance != miss_distance else 0.0)
				_expect(is_equal_approx(dummy.health.current_health, expected), "%s a %.0f px, ángulo %.2f: contacto único o fallo según alcance." % [hand, distance, angle])
		for offset in [Vector2(0, 50), Vector2(-50, 0)]:
			player.stop_combat()
			player.stamina = player.max_stamina
			player.facing_direction = Vector2.RIGHT
			dummy.position = player.position + offset
			dummy.health.reset()
			await _frames(2)
			if hand == "jab":
				player.request_jab()
			else:
				player.request_cross()
			await _frames(50)
			_expect(is_equal_approx(dummy.health.current_health, dummy.health.max_health), "El alcance no debe convertirse en daño lateral o por detrás.")
	_expect(is_equal_approx(player.health.current_health, player.health.max_health), "El boxeador no debe golpearse a sí mismo.")
	stage.queue_free()
	await process_frame
	print("REACH_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
