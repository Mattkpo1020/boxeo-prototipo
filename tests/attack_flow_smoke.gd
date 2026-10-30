extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _frame() -> void:
	await physics_frame
	await process_frame

# Mide el intervalo entre dos ataques reales, al aire, con pulsación pendiente.
func _measure_pair(player: Node, first: BoxingAttack, second: BoxingAttack) -> float:
	player.stamina = 100.0
	var starts: Array[int] = []
	var on_start := func(_direction: Vector2): starts.append(Engine.get_physics_frames())
	player.punch_started.connect(on_start)
	_expect(player._request_attack(first), "Debe iniciar el primer golpe del par.")
	var queued: bool = false
	for index in 120:
		if starts.size() == 2:
			break
		if not queued:
			queued = player._request_attack(second)
		await _frame()
	_expect(starts.size() == 2, "Debe ejecutar el segundo golpe del par.")
	var interval: float = 10.0
	if starts.size() == 2:
		interval = float(starts[1] - starts[0]) / Engine.physics_ticks_per_second
	_expect(is_equal_approx(player.stamina, 100.0 - first.stamina_cost - second.stamina_cost), "Cada golpe debe cobrar su propio coste, también al alternar.")
	for index in 120:
		if player.attack_state == player.AttackState.IDLE:
			break
		await _frame()
	player.punch_started.disconnect(on_start)
	return interval

func _run() -> void:
	var scene: Node = load("res://scenes/combat_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frame()
	var player = scene.get_node("Player")
	# Escenario acotado para comprobar costes y daño independientemente del balance.
	player.max_stamina = 100.0
	player.stamina = 100.0
	var training_health: HealthComponent = scene.get_node("TrainingDummy/Health")
	training_health.max_health = 100.0
	training_health.reset()
	player.stamina_regen = 0.0
	var jab_jab: float = await _measure_pair(player, player.jab, player.jab)
	var jab_cross: float = await _measure_pair(player, player.jab, player.cross)
	var cross_cross: float = await _measure_pair(player, player.cross, player.cross)
	var cross_jab: float = await _measure_pair(player, player.cross, player.jab)
	_expect(jab_jab < cross_cross * 0.6, "El jab debe repetirse claramente más rápido que el cross.")
	_expect(jab_cross < jab_jab, "Cambiar de jab a cross debe enlazar antes que repetir mano.")
	_expect(cross_jab < cross_cross, "Cambiar de cross a jab debe enlazar antes que repetir mano.")
	_expect(jab_cross > player.jab.windup + player.jab.active, "Alternar no debe cancelar la fase activa del jab.")
	_expect(cross_jab > player.cross.windup + player.cross.active, "Alternar debe conservar recuperación tras el cross.")
	_expect(player.jab.damage < player.cross.damage and player.jab.stamina_cost < player.cross.stamina_cost, "El jab debe ser más ligero y económico.")
	_expect(is_equal_approx(scene.get_node("TrainingDummy/Health").current_health, 100.0), "Las secuencias fuera de alcance no deben hacer daño.")
	print("CADENCE (s): jab-jab=", jab_jab, " jab-cross=", jab_cross, " cross-cross=", cross_cross, " cross-jab=", cross_jab)
	scene.queue_free()
	await process_frame
	print("ATTACK_FLOW_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
