extends SceneTree

var _failures: int = 0
var _counts := {"started": 0, "hits": 0, "swings": 0}

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

func _wait_for_late_recovery(player: Node) -> void:
	for index in 100:
		var attack: BoxingAttack = player._attack
		var remaining: float = attack.windup + attack.active + attack.recovery - player._attack_elapsed
		if player.attack_state == player.AttackState.RECOVERY and remaining <= 0.11:
			return
		await _frames(1)
	_expect(false, "No se alcanzó la ventana de encadenamiento.")

func _wait_for_idle(player: Node) -> void:
	for index in 100:
		if player.attack_state == player.AttackState.IDLE:
			return
		await _frames(1)
	_expect(false, "El ataque no finalizó.")

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
	player.stamina_regen = 0.0
	player.position = dummy.position - Vector2(60, 0)
	player.punch_started.connect(func(_direction: Vector2): _counts["started"] += 1)
	player.punch_swung.connect(func(_attack: BoxingAttack): _counts["swings"] += 1)
	player.hit_landed.connect(func(_point: Vector2, _direction: Vector2, _attack: BoxingAttack): _counts["hits"] += 1)
	await _frames(3)
	var dummy_position: Vector2 = dummy.position
	_expect(player.request_jab(), "Debe iniciar el jab.")
	_expect(not player.request_cross(), "No debe guardar pulsaciones demasiado tempranas.")
	for index in 20:
		if _counts["hits"] == 1:
			break
		await _frames(1)
	_expect(_counts["hits"] == 1, "El jab debe emitir un solo impacto.")
	_expect(not scene.get_node("ImpactEffects")._effects.is_empty(), "Un acierto debe generar destello y partículas.")
	_expect(dummy.position == dummy_position, "La reacción visual no debe desplazar la colisión del muñeco.")
	var frozen_position: Vector2 = player.position
	var frozen_attack_time: float = player._attack_elapsed
	player.set_touch_direction(Vector2.LEFT)
	await _frames(1)
	_expect(player.position == frozen_position, "La pausa de impacto debe detener temporalmente al atacante.")
	_expect(is_equal_approx(player._attack_elapsed, frozen_attack_time), "La animación de ataque debe pausarse con el impacto.")
	_expect(is_equal_approx(Engine.time_scale, 1.0) and not paused, "El impacto no debe pausar el juego ni cambiar el reloj global.")
	player.set_touch_direction(Vector2.ZERO)

	await _wait_for_late_recovery(player)
	_expect(player.request_cross(), "Debe aceptar CROSS en la ventana final.")
	_expect(is_equal_approx(player.stamina, 92.0), "Guardar una pulsación todavía no debe cobrar estamina.")
	# Varias pulsaciones reemplazan el único espacio disponible.
	_expect(player.request_jab() and player.request_cross(), "La última pulsación válida debe reemplazar la anterior.")
	for index in 20:
		if _counts["started"] == 2:
			break
		await _frames(1)
	_expect(_counts["started"] == 2 and is_equal_approx(player.stamina, 70.0), "Debe arrancar un único CROSS al terminar el jab.")
	await _wait_for_idle(player)
	await _frames(15)
	_expect(_counts["started"] == 2 and _counts["hits"] == 2 and _counts["swings"] == 2, "Cada ataque debe sonar y conectar una sola vez, sin un tercer golpe automático.")
	_expect(is_equal_approx(dummy.health.current_health, 71.5), "El uno-dos limpio debe hacer 28,5 de daño, incluido el bonus del remate.")
	_expect(scene.get_node("ImpactEffects")._effects.is_empty(), "Los efectos temporales deben eliminarse al terminar.")

	# Guardia y pérdida de foco cancelan el ataque pendiente.
	player.position = dummy.position - Vector2(150, 0)
	await _frames(2)
	player.request_jab()
	await _wait_for_late_recovery(player)
	player.request_cross()
	player.set_touch_block(true)
	await _wait_for_idle(player)
	await _frames(15)
	_expect(_counts["started"] == 3 and is_equal_approx(player.stamina, 62.0), "La guardia debe cancelar el CROSS pendiente.")
	player.set_touch_block(false)
	player.request_jab()
	await _wait_for_late_recovery(player)
	player.request_cross()
	player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _wait_for_idle(player)
	await _frames(15)
	_expect(_counts["started"] == 4, "Cambiar de aplicación debe cancelar el golpe pendiente.")
	_expect(_counts["hits"] == 2, "Los golpes al aire no deben generar impactos.")

	player.stamina = 8.0
	player.request_jab()
	await _wait_for_late_recovery(player)
	player.request_cross()
	await _wait_for_idle(player)
	await _frames(15)
	_expect(_counts["started"] == 5 and is_zero_approx(player.stamina), "El combo debe comprobar la estamina al ejecutarse y no dejar valores negativos.")
	scene.queue_free()
	await process_frame
	print("FEEL_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
