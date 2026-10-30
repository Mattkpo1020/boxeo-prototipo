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
	var scene: Node = load("res://scenes/combat_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	var player = scene.get_node("Player")
	var dummy = scene.get_node("TrainingDummy")
	player.punch_started.connect(func(_direction: Vector2): _starts += 1)
	player.stamina_regen = 0.0
	player.position = dummy.position - Vector2(60, 0)
	await _frames(2)

	_expect(player.request_jab(), "Debe iniciar un jab para llenar la cola.")
	for index in 40:
		if player.attack_state == player.AttackState.RECOVERY and player.remaining_recovery(player.cross) <= 0.12:
			break
		await _frames(1)
	_expect(player.request_cross(), "Debe guardar el cross al final de la recuperación.")
	player._impact_pause_left = 0.2
	player.stop_combat()
	_expect(player.attack_state == player.AttackState.IDLE, "stop_combat debe volver a idle.")
	_expect(not player.is_hit_paused() and not player.has_guard_break(), "No debe dejar pausa de impacto ni guardia rota.")
	var starts_after_stop: int = _starts
	await _frames(20)
	_expect(_starts == starts_after_stop, "Un golpe encolado no debe ejecutarse después de detener el combate.")
	_expect(player.request_jab(), "Tras detener el combate debe poder atacar de nuevo.")
	await _frames(8)
	player.stop_combat()

	player.stamina = 300.0
	starts_after_stop = _starts
	player.set_touch_cross(true)
	await _frames(10)
	_expect(player.attack_state in [player.AttackState.CROSS_PENDING, player.AttackState.CHARGING], "Debe estar preparando o cargando el cross.")
	player.stop_combat()
	player.set_touch_cross(false)
	await _frames(8)
	_expect(player.attack_state == player.AttackState.IDLE and _starts == starts_after_stop, "Soltar el cross tras stop_combat no debe lanzar el golpe.")

	scene.queue_free()
	await process_frame

	var sparring: Node = load("res://scenes/sparring.tscn").instantiate()
	root.add_child(sparring)
	current_scene = sparring
	await _frames(3)
	_expect(sparring.get_node_or_null("TrainingDummy") == null, "El sparring no debe conservar el muñeco de práctica.")
	_expect(is_instance_valid(sparring.get_node("Player").target), "El jugador debe apuntar al rival vivo, no a un nodo liberado.")
	player = sparring.get_node("Player")
	var rival = sparring.get_node("Opponent")
	rival.brain_enabled = false
	rival.stop_combat()
	player.stamina = 300.0
	_starts = 0
	player.punch_started.connect(func(_direction: Vector2): _starts += 1)
	player.set_touch_cross(true)
	await _frames(12)
	rival.health.apply_damage(9999.0)
	_expect(sparring._fight_finished, "El KO del rival debe cerrar el asalto.")
	_expect(not player.is_hit_paused() and player.attack_state == player.AttackState.IDLE, "El resultado debe limpiar carga, cola y pausa local.")
	var starts_at_ko: int = _starts
	player.set_touch_cross(false)
	await _frames(12)
	_expect(_starts == starts_at_ko, "Soltar CROSS después del KO no debe disparar un golpe.")
	_expect(not player.request_jab() and not rival.request_jab(), "Nadie debe atacar con el combate cerrado.")
	_expect(not player.health.recovery_active and not rival.health.recovery_active, "La reserva recuperable debe quedar congelada al terminar.")

	sparring._switch_mode()
	await _frames(8)
	_expect(current_scene != sparring, "Cambiar de modo debe reemplazar la escena.")
	_expect(current_scene.get_node_or_null("TrainingDummy") != null, "El modo práctica debe cargar el muñeco.")
	_expect(current_scene.get_node_or_null("Opponent") == null, "El modo práctica no debe dejar al rival anterior.")
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	print("LIFECYCLE_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
