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

func _touch(index: int, position_on_screen: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position_on_screen
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)

func _idle(player: Node) -> void:
	for index in 120:
		if player.attack_state == player.AttackState.IDLE:
			return
		await _frames(1)
	_expect(false, "El cross debe finalizar.")

func _run() -> void:
	# Los eventos sintéticos usan píxeles de ventana, sin escalado del editor.
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
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
	var controls = scene.get_node("HUD/TouchControls")
	player.stamina_regen = 0.0
	player.punch_started.connect(func(_direction: Vector2): _starts += 1)
	var button: Vector2 = controls.button_centers[&"cross"]

	# Tap normal: se lanza al soltar y conserva el balance del cross.
	_touch(1, button, true)
	await _frames(3)
	_expect(_starts == 0 and is_equal_approx(player.stamina, 100.0), "Mantener no debe atacar ni cobrar energía.")
	_expect(player.attack_state == player.AttackState.CROSS_PENDING and not controls._charging, "Un toque breve debe preparar el recto sin activar la carga visual.")
	_touch(1, button, false)
	await _frames(2)
	_expect(_starts == 1 and is_equal_approx(player.stamina, 78.0), "Un toque breve debe lanzar un cross normal de coste 22.")
	await _idle(player)

	# Carga parcial: verifica escala proporcional y daño real, una sola vez.
	player.stamina = 100.0
	player.position = dummy.position - Vector2(60, 0)
	await _frames(2)
	_touch(2, button, true)
	await _frames(33)
	var partial: float = player.get_cross_charge_ratio()
	_expect(partial > 0.3 and partial < 0.7, "La carga intermedia debe estar entre cero y el máximo.")
	_touch(2, button, false)
	await _frames(2)
	var partial_damage: float = player._attack.damage
	var partial_cost: float = player._attack.stamina_cost
	_expect(partial_damage > 18.0 and partial_damage < 36.0, "La carga parcial debe escalar el daño.")
	_expect(is_equal_approx(partial_damage / 18.0, partial_cost / 22.0), "Daño y consumo deben escalar proporcionalmente.")
	await _idle(player)
	_expect(is_equal_approx(dummy.health.current_health, 100.0 - partial_damage), "El daño cargado debe aplicarse una sola vez.")

	# Mantener más tiempo que el máximo no aumenta daño ni consumo.
	dummy.health.reset()
	player.stamina = 100.0
	_touch(3, button, true)
	await _frames(105)
	_expect(is_equal_approx(player.get_cross_charge_ratio(), 1.0), "La carga debe detenerse en 100 %.")
	_expect(is_equal_approx(controls._charge_ratio, 1.0) and controls._charging, "El indicador debe mostrar el máximo.")
	_expect(is_equal_approx(player.stamina, 100.0), "Mantener la carga no debe consumir repetidamente.")
	_touch(3, button, false)
	await _frames(2)
	_expect(is_equal_approx(player._attack.damage, 36.0) and is_equal_approx(player.stamina, 56.0), "El máximo debe ser 36 de daño y 44 de energía.")
	_expect(player._attack.recovery > player.cross.recovery, "La carga máxima debe tener más recuperación.")
	await _idle(player)
	_expect(is_equal_approx(dummy.health.current_health, 64.0), "El máximo debe restar exactamente 36 de vida.")
	_expect(is_equal_approx(player.cross.damage, 18.0) and is_equal_approx(player.cross.stamina_cost, 22.0), "Cargar no debe modificar el recurso del cross normal.")

	# Carga limitada por energía disponible: no hay rechazo ni valores negativos.
	player.stamina = 30.0
	_touch(4, button, true)
	await _frames(75)
	_expect(player.get_cross_charge_ratio() < 0.4, "La energía disponible debe limitar la carga.")
	_touch(4, button, false)
	await _frames(2)
	_expect(is_zero_approx(player.stamina), "El golpe debe usar como máximo la energía disponible.")
	_expect(player._attack.damage < 36.0, "Sin energía suficiente no debe alcanzar daño máximo.")
	await _idle(player)
	_touch(5, button, true)
	await _frames(2)
	_expect(player.attack_state == player.AttackState.IDLE, "No debe empezar a cargar sin energía para el cross base.")
	_touch(5, button, false)
	await _frames(2)

	# Guardia, cancelación de touch y pérdida de foco nunca disparan al soltar.
	player.stamina = 100.0
	var before: int = _starts
	_touch(6, button, true)
	await _frames(15)
	player.set_touch_block(true)
	_touch(6, button, false)
	await _frames(2)
	_expect(player.is_blocking and _starts == before, "La guardia debe cancelar la carga sin disparar.")
	player.set_touch_block(false)
	_touch(7, button, true)
	await _frames(15)
	_touch(7, button, false, true)
	await _frames(2)
	_expect(player.attack_state == player.AttackState.IDLE and _starts == before, "Cancelar touch no debe lanzar el golpe.")
	_touch(8, button, true)
	await _frames(15)
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	_expect(player.attack_state == player.AttackState.IDLE and not controls._charging and _starts == before, "Cambiar de aplicación debe cancelar la carga y su indicador.")
	_expect(is_equal_approx(player.stamina, 100.0), "Cancelar no debe cobrar el golpe.")

	# El teclado usa el mismo gesto de mantener y soltar.
	Input.action_press("cross")
	await _frames(15)
	_expect(player.attack_state == player.AttackState.CHARGING, "La tecla J debe mantener la carga.")
	Input.action_release("cross")
	await _frames(2)
	_expect(_starts == before + 1, "Soltar la tecla debe lanzar un único cross.")
	await _idle(player)

	player.stamina = 100.0
	before = _starts
	Input.action_press("cross")
	await _frames(10)
	player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(10)
	_expect(player.attack_state == player.AttackState.IDLE, "Una tecla mantenida al perder foco no debe reiniciar la carga.")
	Input.action_release("cross")
	await _frames(2)
	_expect(_starts == before, "Soltar la tecla tras perder foco no debe disparar.")

	# Salir del botón cancela; dos dedos sobre CROSS cuentan como una pulsación.
	_touch(10, button, true)
	await _frames(10)
	var drag := InputEventScreenDrag.new()
	drag.index = 10
	drag.position = button + Vector2(controls.button_radius * 2.0, 0)
	Input.parse_input_event(drag)
	await _frames(2)
	_expect(player.attack_state == player.AttackState.IDLE and _starts == before, "Arrastrar fuera de CROSS debe cancelar la carga.")
	_touch(10, button, false)
	_touch(11, button, true)
	_touch(12, button, true)
	await _frames(2)
	_touch(11, button, false)
	await _frames(2)
	_expect(player.attack_state == player.AttackState.CROSS_PENDING, "Soltar un dedo no debe disparar mientras otro mantenga el toque breve de CROSS.")
	_touch(12, button, false)
	await _frames(2)
	_expect(_starts == before + 1, "Soltar el último dedo debe lanzar un único cross.")
	await _idle(player)

	# Un tap al final del jab conserva el combo; mantener espera la recuperación.
	player.position = dummy.position - Vector2(150, 0)
	player.stamina = 100.0
	before = _starts
	player.request_jab()
	for index in 60:
		if player.attack_state == player.AttackState.RECOVERY and player._get_recovery_end(player.cross) - player._attack_elapsed <= 0.09:
			break
		await _frames(1)
	_touch(13, button, true)
	_touch(13, button, false)
	await _frames(60)
	_expect(_starts == before + 2 and is_equal_approx(player.stamina, 70.0), "El tap debe mantener el combo jab-cross de coste 30.")
	player.stamina = 100.0
	before = _starts
	player.request_jab()
	for index in 60:
		if player.attack_state == player.AttackState.RECOVERY and player._get_recovery_end(player.cross) - player._attack_elapsed <= 0.09:
			break
		await _frames(1)
	_touch(14, button, true)
	await _frames(30)
	_expect(player.attack_state == player.AttackState.CHARGING and _starts == before + 1, "Mantener al encadenar debe comenzar la carga después del jab.")
	_expect(is_equal_approx(player.stamina, 92.0), "La carga pendiente no debe cobrar hasta soltar.")
	_touch(14, button, false)
	await _frames(2)
	_expect(_starts == before + 2, "Soltar tras el jab debe lanzar un único cross cargado.")
	await _idle(player)
	scene.queue_free()
	await process_frame
	print("CHARGE_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
