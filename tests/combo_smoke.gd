extends SceneTree

var _failures: int = 0
var _events: Array[Dictionary] = []

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

func _punch(fighter: Node, attack_id: StringName) -> void:
	var accepted: bool = fighter.request_jab() if attack_id == &"jab" else fighter.request_cross()
	_expect(accepted, "Debe aceptar el golpe de la secuencia.")
	for index in 120:
		if fighter.attack_state == fighter.AttackState.IDLE:
			return
		await _frames(1)
	_expect(false, "El golpe debe completar su recuperación.")

func _prepare(player: Node, dummy: Node) -> void:
	player.stop_combat()
	player.stamina = 300.0
	player.position = dummy.position - Vector2(60, 0)
	player.target = dummy
	dummy.health.reset()
	_events.clear()

func _run() -> void:
	var scene: Node = load("res://scenes/combat_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	var player = scene.get_node("Player")
	var dummy = scene.get_node("TrainingDummy")
	player.stamina_regen = 0.0
	player.combo_connected.connect(func(title: String, bonus: float, _point: Vector2):
		_events.append({"title": title, "bonus": bonus})
	)

	_prepare(player, dummy)
	await _punch(player, &"jab")
	await _punch(player, &"cross")
	_expect(is_equal_approx(dummy.health.current_health, 471.5), "JAB-CROSS debe causar 6 + 22,5 de daño.")
	_expect(_events.size() == 1 and _events[0]["title"] == "UNO-DOS", "Debe reconocer el uno-dos una sola vez.")
	_expect(is_equal_approx(player.stamina, 270.0), "El bonus no debe alterar el coste de 30.")
	_expect(scene.get_node("HUD/ComboMessage").text.contains("UNO-DOS"), "Debe mostrar el nombre y bonus del combo.")
	# El remate anterior no cuenta como inicio de un segundo bonus superpuesto.
	await _punch(player, &"jab")
	_expect(_events.size() == 1 and is_equal_approx(dummy.health.current_health, 465.5), "No debe superponer UNO-DOS y CROSS-JAB con el mismo remate.")

	_prepare(player, dummy)
	await _punch(player, &"jab")
	await _punch(player, &"jab")
	await _punch(player, &"cross")
	_expect(is_equal_approx(dummy.health.current_health, 461.0), "El doble jab-cross debe hacer 39 de daño.")
	_expect(_events.size() == 1 and _events[0]["title"] == "DOBLE JAB + CROSS", "La secuencia larga debe tener prioridad sobre el uno-dos de su final.")
	_expect(is_equal_approx(player.stamina, 262.0), "El combo triple debe seguir costando 38.")

	_prepare(player, dummy)
	await _punch(player, &"cross")
	await _punch(player, &"jab")
	_expect(is_equal_approx(dummy.health.current_health, 473.0), "CROSS-JAB debe causar 18 + 9 de daño.")
	_expect(_events.size() == 1 and is_equal_approx(_events[0]["bonus"], 3.0), "La respuesta rápida debe añadir 3 de daño al jab final.")

	# Fallo, espera excesiva, defensa y recibir daño rompen la cadena.
	_prepare(player, dummy)
	await _punch(player, &"jab")
	player.position = dummy.position - Vector2(150, 0)
	await _punch(player, &"jab")
	player.position = dummy.position - Vector2(60, 0)
	await _punch(player, &"cross")
	_expect(_events.is_empty() and is_equal_approx(dummy.health.current_health, 476.0), "Un golpe al aire debe romper el combo.")
	_prepare(player, dummy)
	await _punch(player, &"jab")
	await _frames(60)
	await _punch(player, &"cross")
	_expect(_events.is_empty(), "La ventana de combo debe caducar.")
	_prepare(player, dummy)
	await _punch(player, &"jab")
	player.set_touch_block(true)
	player.set_touch_block(false)
	await _punch(player, &"cross")
	_expect(_events.is_empty(), "Cubrirse debe abandonar la cadena ofensiva.")
	_prepare(player, dummy)
	await _punch(player, &"jab")
	player.receive_attack(6.0, Vector2.LEFT, 0.0, 0.0)
	await _punch(player, &"cross")
	_expect(_events.is_empty(), "Recibir un golpe limpio debe interrumpir la cadena propia.")

	# Cambiar de objetivo no permite transportar un bonus a otro boxeador.
	_prepare(player, dummy)
	await _punch(player, &"jab")
	var other: Node2D = load("res://scenes/training_dummy.tscn").instantiate()
	scene.add_child(other)
	other.position = dummy.position + Vector2(0, 100)
	player.target = other
	player.position = other.position - Vector2(60, 0)
	await _frames(2)
	await _punch(player, &"cross")
	_expect(_events.is_empty() and is_equal_approx(other.health.current_health, 482.0), "Los golpes deben conectar sobre el mismo objetivo.")
	other.queue_free()
	await process_frame

	# Cargar rompe la cadena y mantiene el límite máximo de daño del cross.
	_prepare(player, dummy)
	await _punch(player, &"jab")
	player.set_touch_cross(true)
	await _frames(75)
	player.set_touch_cross(false)
	for index in 120:
		if player.attack_state == player.AttackState.IDLE: break
		await _frames(1)
	_expect(_events.is_empty() and is_equal_approx(dummy.health.current_health, 458.0), "El cross cargado debe conservar su máximo de 36 sin multiplicar bonus.")
	scene.queue_free()
	await process_frame

	# Bloqueos rompen el combo, y el rival puede obtener los mismos bonus.
	var sparring: Node = load("res://scenes/sparring.tscn").instantiate()
	root.add_child(sparring)
	current_scene = sparring
	await _frames(3)
	player = sparring.get_node("Player")
	var rival = sparring.get_node("Opponent")
	rival.brain_enabled = false
	rival.stop_combat()
	player.stamina_regen = 0.0
	player.position = sparring.ring_rect.get_center() - Vector2(28, 0)
	rival.position = sparring.ring_rect.get_center() + Vector2(28, 0)
	_events.clear()
	player.combo_connected.connect(func(title: String, bonus: float, _point: Vector2): _events.append({"title": title, "bonus": bonus}))
	await _punch(player, &"jab")
	rival.set_touch_block(true)
	await _punch(player, &"cross")
	rival.set_touch_block(false)
	await _punch(player, &"jab")
	_expect(_events.is_empty() and is_equal_approx(rival.health.current_health, 483.5), "Un remate bloqueado debe usar daño base reducido y romper la cadena.")
	player.stop_combat()
	rival.stop_combat()
	player.health.reset()
	rival.stamina = 300.0
	await _punch(rival, &"jab")
	await _punch(rival, &"cross")
	_expect(is_equal_approx(player.health.current_health, 471.5), "El rival debe obtener el mismo bonus de UNO-DOS.")
	sparring.queue_free()
	await process_frame
	print("COMBO_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
