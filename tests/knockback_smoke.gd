extends SceneTree

var _failures: int = 0
var _scene: Node
var _player: FighterBody
var _rival: FighterBody

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

func _reset() -> void:
	_player.stop_combat()
	_rival.stop_combat()
	_player.health.reset()
	_rival.health.reset()
	_player.stamina = _player.max_stamina
	_rival.stamina = _rival.max_stamina
	_player.position = _scene.ring_rect.get_center() - Vector2(28, 0)
	_rival.position = _scene.ring_rect.get_center() + Vector2(28, 0)
	await _frames(2)

func _strike(hand: String, blocked: bool = false) -> float:
	await _reset()
	_rival.set_touch_block(blocked)
	await _frames(2)
	var origin: Vector2 = _rival.position
	if hand == "charged":
		_player.set_touch_cross(true)
		await _frames(78)
		_player.set_touch_cross(false)
	elif hand == "cross":
		_expect(_player.request_cross(), "Debe aceptar cross.")
	else:
		_expect(_player.request_jab(), "Debe aceptar jab.")
	await _frames(60)
	var damage: float = 6.0 if hand == "jab" else (36.0 if hand == "charged" else 18.0)
	_expect(is_equal_approx(_rival.health.current_health, 500.0 - damage * (0.25 if blocked else 1.0)), "El empuje no debe duplicar impactos ni cambiar el daño de " + hand)
	_expect(absf(_rival.position.y - origin.y) < 0.1, "El empuje frontal no debe desplazar lateralmente.")
	var settled: Vector2 = _rival.position
	await _frames(20)
	_expect(_rival.position.distance_to(settled) < 0.01, "El empuje debe frenarse por completo.")
	return _rival.position.x - origin.x

func _run() -> void:
	_scene = load("res://scenes/sparring.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	await _frames(3)
	_player = _scene.get_node("Player")
	_rival = _scene.get_node("Opponent")
	_rival.brain_enabled = false
	_player.stamina_regen = 0.0
	_rival.stamina_regen = 0.0
	var jab_push: float = await _strike("jab")
	var cross_push: float = await _strike("cross")
	var charged_push: float = await _strike("charged")
	var blocked_push: float = await _strike("cross", true)
	_expect(jab_push > 0.5, "El jab debe separar físicamente los cuerpos.")
	_expect(cross_push > jab_push * 2.0, "El cross debe empujar más que el jab.")
	_expect(charged_push > cross_push * 1.5, "La carga debe aumentar perceptiblemente el empuje.")
	_expect(blocked_push < cross_push * 0.3, "Bloquear debe reducir el empuje.")
	_expect(is_equal_approx(_player.cross.knockback_speed, 145.0), "Cargar no debe modificar el recurso compartido.")

	# Los tres combos existentes deben conectar también contra un cuerpo móvil.
	for sequence in [["jab", "cross"], ["jab", "jab", "cross"], ["cross", "jab"]]:
		await _reset()
		for hand in sequence:
			if hand == "jab":
				_player.request_jab()
				await _frames(23)
			else:
				_player.request_cross()
				await _frames(43)
		var expected_damage: float = 28.5 if sequence.size() == 2 and sequence[0] == "jab" else (39.0 if sequence.size() == 3 else 27.0)
		_expect(is_equal_approx(_rival.health.current_health, 500.0 - expected_damage), "El empuje debe permitir el combo " + str(sequence))

	# Paredes, límite de velocidad y dirección diagonal.
	await _reset()
	_rival.position = _scene.ring_rect.end - Vector2(20, 20)
	_player.position = _scene.ring_rect.get_center()
	_rival.receive_attack(18.0, Vector2.ONE.normalized(), 8.0, 0.0, 10000.0)
	_expect(_rival._knockback_velocity.length() <= _rival.max_knockback_speed, "El empuje debe tener un máximo.")
	await _frames(35)
	_expect(_scene.ring_rect.grow(-16).has_point(_rival.position), "El empuje no debe atravesar las paredes del ring.")

	await _reset()
	var origin: Vector2 = _rival.position
	for index in 10:
		_rival.receive_attack(1.0, Vector2.DOWN, 0.0, 0.0, 145.0)
	_expect(_rival._knockback_velocity.length() <= 145.01, "Golpes simultáneos no deben acumular velocidad.")
	await _frames(30)
	_expect(_rival.position.y > origin.y + 5.0 and absf(_rival.position.x - origin.x) < 0.1, "El empuje debe respetar la dirección recibida.")
	_rival.receive_attack(1.0, Vector2.DOWN, 0.0, 0.0, 145.0)
	_rival.stop_combat()
	origin = _rival.position
	await _frames(20)
	_expect(_rival.position == origin, "Detener el combate debe limpiar el empuje pendiente.")

	# La señal de KO cierra el combate durante apply_damage.
	_rival.receive_attack(1000.0, Vector2.RIGHT, 0.0, 0.0, 145.0)
	_expect(_scene._between_rounds and _rival._knockback_velocity.is_zero_approx(), "El KO no debe reintroducir movimiento después del cierre.")
	print("KNOCKBACK DISTANCES: jab=", jab_push, " cross=", cross_push, " charged=", charged_push, " blocked=", blocked_push)
	_scene.queue_free()
	await process_frame
	print("KNOCKBACK_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
