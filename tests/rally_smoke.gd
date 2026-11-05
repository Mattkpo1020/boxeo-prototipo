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

func _punch(fighter: Node, attack_id: StringName) -> void:
	_expect(fighter.request_jab() if attack_id == &"jab" else fighter.request_cross(), "Debe aceptar el ataque de recuperación.")
	for index in 120:
		if fighter.attack_state == fighter.AttackState.IDLE: return
		await _frames(1)
	_expect(false, "El ataque debe completar su recuperación.")

func _run() -> void:
	# Aritmética y reloj aislados del renderizado y los impactos.
	var health := HealthComponent.new()
	health.max_health = 500.0
	root.add_child(health)
	health.set_physics_process(false)
	health.apply_damage(100.0)
	_expect(is_equal_approx(health.current_health, 400.0) and is_equal_approx(health.recoverable_health, 60.0), "Recibir 100 debe dejar 400 reales y 60 recuperables.")
	health.advance_recovery(0.5)
	_expect(is_equal_approx(health.recoverable_health, 60.0), "La reserva debe respetar la demora inicial.")
	health.advance_recovery(1.0)
	_expect(is_equal_approx(health.recoverable_health, 54.0), "Al cruzar la demora solo debe descontar el tiempo posterior.")
	_expect(is_equal_approx(health.restore_from_damage(20.0), 10.0), "Causar 20 debe recuperar 10 puntos.")
	_expect(is_equal_approx(health.current_health, 410.0) and is_equal_approx(health.recoverable_health, 44.0), "La curación debe convertir reserva amarilla en vida real.")
	health.advance_recovery(100.0)
	_expect(is_zero_approx(health.recoverable_health) and is_equal_approx(health.current_health, 410.0), "Agotar la reserva no debe quitar vida adicional.")
	_expect(is_zero_approx(health.restore_from_damage(1000.0)), "Sin reserva no debe curar.")
	health.reset()
	health.apply_damage(100.0)
	health.apply_damage(100.0)
	_expect(is_equal_approx(health.current_health, 300.0) and is_equal_approx(health.recoverable_health, 120.0), "El daño sucesivo debe acumular una reserva acotada.")
	health.restore_from_damage(10000.0)
	_expect(is_equal_approx(health.current_health, 420.0) and is_zero_approx(health.recoverable_health), "La curación no debe superar la reserva disponible.")
	health.apply_damage(9999.0)
	_expect(is_zero_approx(health.current_health) and is_zero_approx(health.recoverable_health), "Un KO debe eliminar la reserva.")
	_expect(is_zero_approx(health.restore_from_damage(10000.0)), "La reserva no debe resucitar a un derrotado.")
	health.reset()
	_expect(is_equal_approx(health.current_health, 500.0) and is_zero_approx(health.recoverable_health), "El reinicio debe restaurar la vida y limpiar la reserva.")
	health.queue_free()
	await process_frame

	var scene: Node = load("res://scenes/sparring.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	var player = scene.get_node("Player")
	var rival = scene.get_node("Opponent")
	rival.brain_enabled = false
	rival.stop_combat()
	player.position = scene.ring_rect.get_center() - Vector2(28, 0)
	rival.position = scene.ring_rect.get_center() + Vector2(28, 0)
	# El reloj de decadencia ya se comprobó arriba; aquí se aíslan golpes reales.
	player.health.set_physics_process(false)
	rival.health.set_physics_process(false)
	player.health.apply_damage(100.0)
	rival.health.apply_damage(100.0)
	_expect(is_equal_approx(scene.get_node("HUD/PlayerHealth").value, 400.0), "La barra principal debe mostrar vida real.")
	_expect(is_equal_approx(scene.get_node("HUD/PlayerRecoverable").value, 460.0), "La reserva amarilla debe extenderse hasta vida real más recuperable.")
	_expect(scene.get_node("HUD/PlayerHealthLabel").text.contains("[+60]"), "El HUD debe indicar cuánta vida queda por recuperar.")
	await _punch(player, &"jab")
	_expect(is_equal_approx(player.health.current_health, 403.0) and is_equal_approx(player.health.recoverable_health, 57.0), "Un jab limpio debe recuperar 3 de la reserva.")
	_expect("CURÓ +3.0" in scene.get_node("HUD/PlayerHealthLabel").text, "El HUD debe distinguir lo curado de la reserva pendiente.")
	await _punch(player, &"cross")
	_expect(is_equal_approx(player.health.current_health, 414.25) and is_equal_approx(player.health.recoverable_health, 45.75), "El remate de combo debe recuperar la mitad del daño efectivo de 22,5.")
	_expect(is_equal_approx(scene.get_node("HUD/PlayerRecoverable").value, 460.0), "Recuperar debe convertir el amarillo en vida real sin ampliar el total.")
	await _frames(62)
	_expect(not ("CURÓ" in scene.get_node("HUD/PlayerHealthLabel").text), "El aviso de curación debe desaparecer.")
	rival.health.advance_recovery(0.9)
	rival.set_touch_block(true)
	await _punch(player, &"cross")
	_expect(is_equal_approx(player.health.current_health, 414.25), "Los golpes sobre guardia no deben dar recuperación.")
	var reserve_after_block: float = rival.health.recoverable_health
	rival.health.advance_recovery(0.2)
	_expect(is_equal_approx(rival.health.recoverable_health, reserve_after_block - 1.2), "Bloquear no debe reiniciar la demora de una reserva existente.")
	rival.set_touch_block(false)
	player.position = rival.position - Vector2(150, 0)
	await _punch(player, &"cross")
	_expect(is_equal_approx(player.health.current_health, 414.25), "Golpear al aire no debe recuperar vida.")
	player.position = rival.position - Vector2(56, 0)
	player.health.reset()
	rival.health.reset()
	rival.health.apply_damage(100.0)
	await _punch(rival, &"jab")
	_expect(is_equal_approx(rival.health.current_health, 403.0) and is_equal_approx(rival.health.recoverable_health, 57.0), "El rival debe recuperar con la misma regla.")
	player.health.apply_damage(9999.0)
	var frozen_reserve: float = rival.health.recoverable_health
	rival.health.advance_recovery(100.0)
	_expect(is_equal_approx(rival.health.recoverable_health, frozen_reserve) and is_zero_approx(rival.health.restore_from_damage(1000.0)), "El resultado debe congelar la reserva e impedir curación posterior.")
	scene.queue_free()
	await process_frame

	# Overkill: solo cuenta el daño que el objetivo realmente podía recibir.
	var practice: Node = load("res://scenes/combat_test.tscn").instantiate()
	root.add_child(practice)
	current_scene = practice
	await _frames(3)
	player = practice.get_node("Player")
	var dummy = practice.get_node("TrainingDummy")
	player.health.set_physics_process(false)
	player.health.apply_damage(100.0)
	dummy.health.current_health = 4.0
	player.position = dummy.position - Vector2(60, 0)
	await _punch(player, &"cross")
	_expect(is_equal_approx(player.health.current_health, 402.0), "Un cross contra 4 de vida debe recuperar solo 2, no la mitad de su daño nominal.")
	practice.queue_free()
	await process_frame
	print("RALLY_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
