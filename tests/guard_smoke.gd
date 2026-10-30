extends SceneTree

var _failures: int = 0
var _starts: int = 0

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
	var player: FighterBody = scene.get_node("Player")
	var rival = scene.get_node("Opponent")
	rival.brain_enabled = false
	rival.stop_combat()
	player.stop_combat()
	player.position = scene.ring_rect.get_center()
	rival.position = player.position + Vector2(150, 0)
	player.stamina_regen = 0.0
	player.punch_started.connect(func(_direction: Vector2): _starts += 1)
	await _frames(2)

	# Cobertura frontal y coste exacto, incluidos golpes laterales y traseros.
	player.set_touch_block(true)
	player.stamina = 14.4
	player.receive_attack(18.0, Vector2.LEFT, 0.0, 0.0)
	_expect(is_equal_approx(player.health.current_health, 495.5), "La guardia debe conservar la reducción del 75 %.")
	_expect(is_zero_approx(player.stamina) and not player.has_guard_break(), "La energía exacta debe permitir bloquear sin romperse.")
	player.stamina = 100.0
	player.receive_attack(6.0, Vector2.UP, 0.0, 0.0)
	player.receive_attack(6.0, Vector2.RIGHT, 0.0, 0.0)
	_expect(is_equal_approx(player.health.current_health, 483.5) and is_equal_approx(player.stamina, 100.0), "La guardia no debe cubrir costados ni espalda.")
	player.set_touch_cross(true)
	_expect(player.attack_state == FighterBody.AttackState.IDLE, "Bloquear debe impedir cargar.")
	player.set_touch_cross(false)

	# La ruptura deja pasar daño completo y una ventana que no se renueva con cada golpe.
	player.stamina = 1.0
	player.receive_attack(18.0, Vector2.LEFT, 0.0, 0.0)
	_expect(player.has_guard_break() and not player.is_blocking, "Sin energía debe romperse la guardia.")
	_expect(is_zero_approx(player.stamina) and is_equal_approx(player.health.current_health, 465.5), "La ruptura consume la reserva y deja pasar el golpe completo.")
	_expect(scene.get_node("HUD/PlayerDefense").text == "GUARDIA ROTA", "Debe mostrar la ruptura en el HUD.")
	var remaining: float = player.get_guard_break_remaining()
	player.receive_attack(6.0, Vector2.LEFT, 0.0, 0.0)
	_expect(is_equal_approx(player.get_guard_break_remaining(), remaining), "Los impactos durante la ruptura no deben prolongarla indefinidamente.")
	player.set_touch_block(false)
	# Energía artificial para comprobar que las acciones se rechazan por ruptura,
	# independientemente del agotamiento.
	player.stamina = 300.0
	_expect(not player.request_jab() and not player.request_cross() and not player.try_punch(), "Todas las entradas de ataque deben respetar la ruptura.")
	player.set_touch_cross(true)
	_expect(player.attack_state == FighterBody.AttackState.IDLE, "La ruptura debe impedir preparar/cargar el cross.")
	player.set_touch_direction(Vector2.LEFT)
	Input.action_press("sprint")
	var origin: Vector2 = player.position
	await _frames(12)
	var travel: float = player.position.distance_to(origin)
	_expect(travel > 5.0 and travel < 16.0, "Debe poder retirarse lentamente, sin correr.")
	_expect(is_equal_approx(player.stamina, 300.0), "Un intento de correr durante la ruptura no debe consumir energía.")
	Input.action_release("sprint")
	player.set_touch_direction(Vector2.ZERO)
	await _frames(24)
	_expect(not player.has_guard_break() and scene.get_node("HUD/PlayerDefense").text.is_empty(), "Debe terminar la penalización y limpiar el aviso.")
	player.set_touch_cross(false)
	_expect(_starts == 0, "Soltar CROSS después de la ruptura no debe lanzar una carga rechazada.")
	_expect(player.request_jab(), "Debe poder volver a atacar al terminar la ventana.")
	await _frames(30)

	# La pausa de impacto congela el reloj local de la ruptura.
	player.stop_combat()
	player.set_touch_block(true)
	player.stamina = 1.0
	player.receive_attack(18.0, Vector2.LEFT, 0.0, 0.1)
	remaining = player.get_guard_break_remaining()
	await _frames(3)
	_expect(is_equal_approx(player.get_guard_break_remaining(), remaining), "La ventana no debe agotarse durante la pausa local.")
	player.stop_combat()
	_expect(not player.has_guard_break() and scene.get_node("HUD/PlayerDefense").text.is_empty(), "Detener el combate debe limpiar la ruptura y el HUD.")

	# Bajar la guardia permite recuperar energía más rápido.
	player.stamina_regen = 30.0
	player.stamina = 100.0
	player._regen_time_left = 0.0
	player.set_touch_block(true)
	await _frames(60)
	var guarded_gain: float = player.stamina - 100.0
	player.set_touch_block(false)
	player.stamina = 100.0
	await _frames(60)
	var free_gain: float = player.stamina - 100.0
	_expect(guarded_gain > 0.0 and guarded_gain / free_gain > 0.3 and guarded_gain / free_gain < 0.4, "La guardia debe regenerar al 35 % del ritmo libre.")

	# El rival comparte la penalización y su indicador; KO limpia ambos.
	rival.set_touch_block(true)
	rival.stamina = 1.0
	rival.receive_attack(18.0, Vector2.RIGHT, 0.0, 0.0)
	_expect(rival.has_guard_break() and scene.get_node("HUD/OpponentDefense").text == "GUARDIA ROTA", "El rival debe compartir reglas y aviso de ruptura.")
	rival.health.apply_damage(1000.0)
	_expect(scene._fight_finished and not rival.has_guard_break(), "El KO debe limpiar la penalización.")
	_expect(scene.get_node("HUD/OpponentDefense").text.is_empty(), "No debe quedar un aviso de ruptura después del KO.")
	scene.queue_free()
	await process_frame
	print("GUARD_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
