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
	var dummy = scene.get_node("TrainingDummy")
	var health: HealthComponent = dummy.get_node("Health")
	player.stamina_regen = 0.0
	_expect(player.facing_direction.dot(Vector2.RIGHT) > 0.99, "Debe mirar al muñeco.")
	_expect(player.try_punch(), "Debe aceptar el primer jab.")
	_expect(is_equal_approx(player.stamina, 92.0), "El jab debe costar 8 de estamina.")
	_expect(not player.try_punch(), "No puede encadenar golpes durante la preparación.")
	await _frames(32)
	_expect(is_equal_approx(health.current_health, 100.0), "Un jab lejano no debe causar daño.")

	player.position = dummy.position - Vector2(60, 0)
	await _frames(3)
	_expect(player.try_punch(), "Debe aceptar un nuevo jab tras recuperarse.")
	await _frames(3)
	_expect(is_equal_approx(health.current_health, 100.0), "La preparación no debe hacer daño.")
	await _frames(10)
	_expect(is_equal_approx(health.current_health, 94.0), "El jab debe hacer 6 de daño una sola vez.")
	_expect(not player.try_punch(), "La recuperación debe impedir un nuevo jab.")
	await _frames(20)
	_expect(is_equal_approx(health.current_health, 94.0), "La recuperación no debe repetir daño.")
	_expect(is_equal_approx(scene.get_node("HUD/DummyHealth").value, 94.0), "La barra debe reflejar el daño.")

	for index in 10:
		_expect(player.try_punch(), "Debe poder usar la estamina restante.")
		await _frames(30)
	_expect(is_equal_approx(player.stamina, 4.0), "Doce jabs deben gastar 96 de estamina.")
	_expect(not player.try_punch(), "No debe golpear sin estamina suficiente.")
	player.stamina_regen = 18.0
	await _frames(90)
	_expect(player.stamina > 4.0, "Debe regenerar estamina tras una pausa.")

	# Verifica derrota, rechazo de daño posterior y reinicio del componente.
	health.apply_damage(1000.0)
	_expect(is_zero_approx(health.current_health), "La vida no debe bajar de cero.")
	_expect(not health.apply_damage(10.0), "Un objetivo derrotado no debe recibir más daño.")
	health.reset()
	_expect(is_equal_approx(health.current_health, 100.0), "El reinicio debe restaurar la vida.")
	scene.queue_free()
	await process_frame
	print("COMBAT_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
