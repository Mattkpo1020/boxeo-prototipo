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
	var scene: Node = load("res://scenes/sparring.tscn").instantiate()
	scene.break_duration = 1.0
	root.add_child(scene)
	current_scene = scene
	var player: FighterBody = scene.get_node("Player")
	var rival = scene.get_node("Opponent")
	rival.brain_enabled = false
	player.stamina_regen = 0.0
	rival.stamina_regen = 0.0
	player.stamina = 260.0
	rival.stamina = 100.0
	rival.health.apply_damage(20.0)
	await _frames(3660)
	_expect(scene._round_number == 1 and player.can_fight(), "El asalto sigue activo al pasar un minuto.")
	rival.health.apply_damage(1000.0)
	_expect(scene._between_rounds and not scene._fight_finished, "El primer nocaut debe abrir un descanso.")
	_expect(scene.get_node("HUD/PlayerRounds").text == "●○", "El primer nocaut debe llenar un punto del jugador.")
	_expect(not player.request_jab() and not rival.request_cross(), "El descanso debe bloquear ataques de ambos lados.")
	var before_pause: float = scene._break_time_left
	paused = true
	await _frames(20)
	_expect(is_equal_approx(scene._break_time_left, before_pause), "Pausar debe congelar el descanso.")
	paused = false
	await _frames(65)
	_expect(scene._round_number == 2 and not scene._between_rounds and player.can_fight() and rival.can_fight(), "Debe comenzar el segundo asalto.")
	_expect(is_equal_approx(player.stamina, 300.0) and is_equal_approx(rival.stamina, 300.0), "El nuevo asalto debe empezar con energía completa.")
	_expect(is_equal_approx(rival.health.current_health, 500.0) and is_zero_approx(rival.health.recoverable_health), "El nuevo asalto debe restaurar la vida y limpiar la reserva.")
	_expect(player.position.distance_to(rival.position) > 100.0, "El nuevo asalto debe separar a los boxeadores.")
	player.health.apply_damage(1000.0)
	_expect(scene._between_rounds and scene.get_node("HUD/OpponentRounds").text == "●○", "El empate 1 a 1 debe llevar a un desempate.")
	await _frames(65)
	_expect(scene._round_number == 3 and player.can_fight() and rival.can_fight(), "Debe comenzar el asalto de desempate.")
	rival.health.apply_damage(1000.0)
	_expect(scene._fight_finished and not player.can_fight() and not rival.can_fight(), "Dos victorias deben cerrar el encuentro.")
	_expect(scene.get_node("HUD/PlayerRounds").text == "●●" and "Ganaste el combate" in scene.get_node("HUD/Feedback").text, "El resultado debe mostrar las dos victorias.")
	scene._restart()
	await _frames(3)
	var restarted: Node = current_scene
	_expect(restarted != scene and restarted._round_number == 1 and not restarted._fight_finished, "Reiniciar debe volver al primer asalto.")
	_expect(restarted.get_node("HUD/PlayerRounds").text == "○○" and restarted.get_node("HUD/OpponentRounds").text == "○○", "Reiniciar debe limpiar el marcador.")
	restarted.queue_free()
	await process_frame
	print("ROUNDS_SMOKE: ", "PASS" if _failures == 0 else "FAIL")
	quit(0 if _failures == 0 else 1)
