extends SceneTree

var _failures: int = 0
var _player: FighterBody
var _rival: FighterBody
var _origin: Vector2

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

func _reset(distance: float) -> void:
	_player.stop_combat()
	_rival.stop_combat()
	_player.health.reset()
	_rival.health.reset()
	_player.stamina = 300.0
	_rival.stamina = 300.0
	_player.position = _origin
	_rival.position = _origin + Vector2(distance, 0)
	await _frames(2)

func _evade_jab() -> void:
	await _reset(54.0)
	_expect(_rival.request_jab(), "Debe comenzar el jab rival.")
	await _frames(1)
	_expect(_player.request_dodge(), "Debe comenzar la esquiva después de la preparación rival.")
	await _frames(24)
	_expect(is_equal_approx(_player.health.current_health, 500.0), "La esquiva debe evitar el jab.")
	_expect(_rival.attack_state == FighterBody.AttackState.IDLE, "El jab rival ya debe haber salido de recuperación.")

func _run() -> void:
	var scene: Node = load("res://scenes/sparring.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(2)
	_player = scene.get_node("Player")
	var rival = scene.get_node("Opponent")
	rival.brain_enabled = false
	_rival = rival
	_rival.stamina_regen = 0.0
	_origin = scene.ring_rect.get_center()
	_player.dodge_speed = 0.0 # Mantiene el contacto geométrico para aislar la ventana evasiva.

	await _reset(135.0)
	_expect(_rival.request_cross(), "Debe comenzar el cross que va a fallar.")
	await _frames(19)
	_expect(_rival.attack_state == FighterBody.AttackState.RECOVERY, "El cross fallado debe estar en recuperación.")
	_rival.position = _origin + Vector2(54, 0)
	_expect(_player.request_jab(), "Debe poder responder al cross fallado.")
	await _frames(10)
	_expect(is_equal_approx(_rival.health.current_health, 492.5), "El jab debe sumar 25 % durante la recuperación del fallo.")
	_expect("CONTRAATAQUE" in scene.get_node("HUD/ComboMessage").text, "El HUD debe anunciar el contraataque.")

	await _evade_jab()
	_expect(_player.request_jab(), "Debe poder responder al terminar la esquiva.")
	await _frames(10)
	_expect(is_equal_approx(_rival.health.current_health, 492.5), "La esquiva debe dar bonus aunque el rival ya esté en reposo.")

	await _evade_jab()
	await _frames(24)
	_expect(_player.request_jab(), "Debe poder atacar tras el vencimiento de la ventana.")
	await _frames(10)
	_expect(is_equal_approx(_rival.health.current_health, 494.0), "Una respuesta tardía debe hacer daño normal.")

	await _evade_jab()
	_rival.set_touch_block(true)
	_expect(_player.request_jab(), "Debe poder atacar contra la guardia.")
	await _frames(10)
	_expect(is_equal_approx(_rival.health.current_health, 498.5), "Un jab bloqueado debe hacer su daño reducido habitual.")
	_expect(is_equal_approx(_rival.stamina, 287.2), "El contraataque bloqueado no debe cobrar estamina adicional al defensor.")

	scene.queue_free()
	await process_frame
	print("COUNTER_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
