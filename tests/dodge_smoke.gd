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
	_player.stamina = 300.0
	_rival.stamina = 300.0
	_player.position = _scene.ring_rect.get_center()
	_rival.position = _player.position + Vector2(150, 0)
	await _frames(2)

func _touch(index: int, position_on_screen: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position_on_screen
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	# El viewport headless comienza en 64x64; los eventos necesitan el tamaño
	# real de juego para llegar a los controles en sus coordenadas de pantalla.
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	_scene = load("res://scenes/sparring.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	await _frames(3)
	_player = _scene.get_node("Player")
	_rival = _scene.get_node("Opponent")
	_rival.brain_enabled = false
	_player.stamina_regen = 0.0
	await _reset()
	var origin: Vector2 = _player.position
	_expect(_player.request_dodge(), "Debe aceptar la esquiva desde reposo.")
	_expect(is_equal_approx(_player.stamina, 282.0), "La esquiva debe costar 18 una sola vez.")
	_expect(not _player.request_dodge(), "No debe repetirse durante el paso.")
	_expect(not _player.request_jab() and not _player.request_cross(), "No debe atacar durante la esquiva.")
	_player.set_touch_block(true)
	_expect(not _player.is_blocking, "No debe combinar esquiva y guardia.")
	_player.set_touch_block(false)
	await _frames(13)
	_expect(_player.attack_state == FighterBody.AttackState.DODGE_RECOVERY, "El paso debe tener recuperación propia.")
	_expect(_player.position.x < origin.x - 45.0 and _player.position.x > origin.x - 65.0, "Sin joystick debe dar un paso atrás de unos 55 px.")
	_expect(not _player.request_jab(), "No debe cancelar la recuperación atacando.")
	await _frames(10)
	_expect(not _player.is_dodge_busy() and not _player.request_dodge(), "Al acabar el paso debe quedar una espera entre esquivas.")
	_expect(_player.request_jab(), "Debe poder atacar después de la recuperación.")
	await _frames(25)
	_expect(_player.request_dodge(), "Tras el enfriamiento debe poder esquivar otra vez.")

	await _reset()
	_player.set_touch_direction(Vector2(1, 1))
	_expect(_player.request_dodge(), "Debe aceptar dirección diagonal.")
	_player.set_touch_direction(Vector2.ZERO)
	origin = _player.position
	await _frames(12)
	var travel: Vector2 = _player.position - origin
	_expect(travel.x > 30.0 and absf(travel.x - travel.y) < 0.1 and travel.length() < 65.0, "El paso diagonal debe conservar distancia y dirección al soltar el joystick.")

	# Ventana evasiva, con el mismo circuito de recepción que usan los ataques.
	await _reset()
	_player.request_dodge()
	_expect(_player.get_node("Hurtbox").receive_hit(6.0, Vector2.LEFT), "Al empezar todavía debe ser vulnerable.")
	_expect(_player.attack_state == FighterBody.AttackState.DODGE_RECOVERY, "Un impacto temprano debe cortar el paso.")
	await _reset()
	_player.request_dodge()
	await _frames(4)
	_expect(_player.is_evading(), "Debe existir una ventana evasiva breve.")
	_expect(not _player.get_node("Hurtbox").receive_hit(18.0, Vector2.LEFT, 8.0, 0.055, 145.0), "Dentro de la ventana debe evitar daño y empuje.")
	_expect(is_equal_approx(_player.health.current_health, 500.0) and _player._knockback_velocity.is_zero_approx(), "Esquivar no debe quitar vida ni generar empuje.")
	await _frames(5)
	_expect(not _player.is_evading(), "La protección debe acabar antes que el paso.")
	_expect(_player.get_node("Hurtbox").receive_hit(6.0, Vector2.LEFT), "Una esquiva tardía debe recibir el impacto.")

	# Un golpe con ventana activa larga puede conectar cuando termina la evasión.
	await _reset()
	_player.dodge_speed = 0.0 # Aísla el tiempo evasivo de la salida física de alcance.
	_rival.position = _player.position + Vector2(56, 0)
	await _frames(2)
	_player.request_dodge()
	await _frames(4)
	var long_jab: BoxingAttack = _rival.jab.duplicate() as BoxingAttack
	long_jab.windup = 0.02
	long_jab.active = 0.25
	_rival._request_attack(long_jab)
	await _frames(30)
	_expect(is_equal_approx(_player.health.current_health, 494.0), "Un golpe que dura más que la evasión debe conectar una sola vez al terminar la protección.")
	_player.dodge_speed = 300.0

	await _reset()
	_player.stamina = 17.0
	_expect(not _player.request_dodge() and is_equal_approx(_player.stamina, 17.0), "No debe esquivar ni gastar energía si no alcanza.")
	_player.stamina = 300.0
	_player.request_jab()
	_expect(not _player.request_dodge(), "No debe cancelar un golpe con esquiva.")
	await _reset()
	_player.set_touch_cross(true)
	_expect(not _player.request_dodge(), "No debe cancelar la preparación de carga con esquiva.")
	await _reset()
	_player.set_touch_block(true)
	_player.stamina = 1.0
	_player.receive_attack(18.0, Vector2.LEFT, 0.0, 0.0)
	_player.stamina = 300.0
	_expect(not _player.request_dodge(), "No debe esquivar durante la ruptura de guardia.")
	await _reset()
	_player.receive_attack(6.0, Vector2.LEFT, 0.0, 0.1)
	_expect(not _player.request_dodge(), "No debe esquivar durante la pausa de impacto.")

	# Paredes y limpieza al detener / perder foco.
	await _reset()
	_player.position.x = _scene.ring_rect.position.x + 20.0
	_player.request_dodge()
	await _frames(22)
	_expect(_scene.ring_rect.grow(-16).has_point(_player.position), "La esquiva no debe atravesar las paredes.")
	await _reset()
	_player.request_dodge()
	await _frames(4)
	_player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(not _player.is_dodge_busy() and not _player.is_evading(), "Perder foco debe cancelar la esquiva y su protección.")
	_expect(_player.get_dodge_cooldown_remaining() > 0.0, "Perder foco no debe regalar otra esquiva inmediata.")
	_player.stop_combat()
	_expect(is_zero_approx(_player.get_dodge_cooldown_remaining()), "Reiniciar debe limpiar la espera de esquiva.")

	# Joystick y esquiva con dedos independientes; mantener el botón no repite.
	await _reset()
	var controls = _scene.get_node("HUD/TouchControls")
	_touch(0, controls.joystick_center + Vector2(0, -controls.joystick_radius * 0.8), true)
	_touch(1, controls.button_centers[&"dodge"], true)
	await _frames(4)
	_expect(_player.is_dodge_busy() and is_equal_approx(_player.stamina, 282.0), "El segundo dedo debe esquivar mientras se mueve el joystick.")
	await _frames(42)
	_expect(not _player.is_dodge_busy() and is_equal_approx(_player.stamina, 282.0), "Mantener el botón después del enfriamiento no debe repetir la esquiva.")
	_touch(1, controls.button_centers[&"dodge"], false)
	_expect(not _player._touch_direction.is_zero_approx(), "Soltar esquiva no debe soltar el joystick.")
	_touch(0, controls.joystick_center, false)
	await _frames(45)
	_expect(is_equal_approx(_player.stamina, 282.0), "Una pulsación no debe repetir esquivas.")
	await _reset()
	Input.action_press("dodge")
	await _frames(3)
	Input.action_release("dodge")
	_expect(_player.is_dodge_busy(), "El teclado debe ejecutar la misma esquiva.")
	_rival.health.apply_damage(1000.0)
	_expect(not _player.is_dodge_busy() and not _player.is_evading() and not _player.request_dodge(), "El fin del combate debe limpiar y bloquear esquivas.")
	_scene.queue_free()
	await process_frame
	print("DODGE_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
