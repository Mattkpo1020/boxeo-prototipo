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
	scene.total_rounds = 2
	scene.round_duration = 1.0
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
	await _frames(20)
	var before_pause: float = scene._round_time_left
	paused = true
	await _frames(20)
	_expect(is_equal_approx(scene._round_time_left, before_pause), "Pausar debe congelar el reloj del asalto.")
	paused = false
	await _frames(45)
	_expect(scene._between_rounds and not scene._fight_finished, "El primer asalto debe abrir un descanso.")
	_expect(not player.request_jab() and not rival.request_cross(), "El descanso debe bloquear ataques de ambos lados.")
	var reserve: float = rival.health.recoverable_health
	await _frames(30)
	_expect(is_equal_approx(rival.health.recoverable_health, reserve), "El descanso debe conservar la reserva.")
	await _frames(35)
	_expect(scene._round_number == 2 and not scene._between_rounds and player.can_fight() and rival.can_fight(), "Debe comenzar el segundo asalto.")
	_expect(is_equal_approx(player.stamina, 300.0) and is_equal_approx(rival.stamina, 160.0), "El descanso debe devolver 60 de estamina hasta el máximo.")
	_expect(is_equal_approx(rival.health.current_health, 480.0), "El descanso debe conservar la vida.")
	_expect(player.position.distance_to(rival.position) > 100.0, "El nuevo asalto debe separar a los boxeadores.")
	await _frames(65)
	_expect(scene._fight_finished and not player.can_fight() and not rival.can_fight(), "El último reloj debe cerrar el encuentro.")
	_expect("Ganaste por decisión" in scene.get_node("HUD/Feedback").text, "Debe ganar quien tenga mayor proporción de vida.")
	scene._restart()
	await _frames(3)
	var restarted: Node = current_scene
	_expect(restarted != scene and restarted._round_number == 1 and not restarted._fight_finished, "Reiniciar debe volver al primer asalto.")
	restarted.get_node("Opponent").brain_enabled = false
	restarted.total_rounds = 1
	restarted._round_time_left = 0.01
	await _frames(3)
	_expect("Empate" in restarted.get_node("HUD/Feedback").text, "La misma proporción de vida debe producir un empate.")
	restarted.queue_free()
	await process_frame
	print("ROUNDS_SMOKE: ", "PASS" if _failures == 0 else "FAIL")
	quit(0 if _failures == 0 else 1)
