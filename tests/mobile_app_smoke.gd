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

func _tap(point: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = point
	touch.pressed = true
	Input.parse_input_event(touch)
	await _frames(1)
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = point
	touch.pressed = false
	Input.parse_input_event(touch)
	await _frames(3)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(30)
	_expect(menu.get_node_or_null("Player") == null and not menu._leaving, "El inicio no debe cargar peleadores ni comenzar el combate solo.")
	var play: Button = menu._actions.get_child(0)
	await _tap(play.get_global_rect().get_center())
	_expect(current_scene != menu and current_scene.get_node_or_null("Opponent") != null, "El botón inicial debe aceptar un toque real y abrir sparring.")
	var scene: Node = current_scene
	var player: FighterBody = scene.get_node("Player")
	var rival: FighterBody = scene.get_node("Opponent")
	var controller: Node = scene.get_node("CombatPause")
	player.set_touch_cross(true)
	await _frames(12)
	controller.pause_combat()
	_expect(paused and controller._overlay.visible, "Pausar debe mostrar el menú y detener el árbol.")
	_expect(player.attack_state == FighterBody.AttackState.IDLE and not player._touch_cross_held, "La pausa debe cancelar carga y entradas touch.")
	var player_position: Vector2 = player.position
	var rival_position: Vector2 = rival.position
	var energy: float = player.stamina
	var hp: float = player.health.current_health
	player.health.recoverable_health = 20.0
	player.health._decay_delay_left = 0.0
	await _frames(90)
	_expect(player.position == player_position and rival.position == rival_position, "La pausa debe congelar movimiento e IA.")
	_expect(is_equal_approx(player.stamina, energy) and is_equal_approx(player.health.current_health, hp) and is_equal_approx(player.health.recoverable_health, 20.0), "La pausa debe congelar energía, vida y reserva amarilla.")
	await _tap(controller._resume_button.get_global_rect().get_center())
	_expect(not paused and not controller._overlay.visible, "Continuar debe funcionar con touch mientras el árbol está pausado.")
	player.set_touch_cross(false)
	_expect(player.attack_state == FighterBody.AttackState.IDLE, "Volver de pausa no debe lanzar un cross viejo.")

	# El canvas se adapta al formato del teléfono, sin franjas por aspecto fijo.
	root.size = Vector2i(844, 390)
	await _frames(4)
	var logical: Vector2 = root.get_visible_rect().size
	_expect(absf(logical.x / logical.y - 844.0 / 390.0) < 0.01, "El viewport debe conservar el aspecto real del celular.")
	_expect(is_equal_approx(scene.ring_rect.size.x, scene.ring_rect.size.y), "El ring debe seguir cuadrado en el nuevo formato.")
	root.size = Vector2i(390, 844)
	await _frames(4)
	_expect(paused and controller._resume_button.disabled, "Girar a vertical debe pausar el combate y bloquear reanudación.")
	root.size = Vector2i(844, 390)
	await _frames(4)
	_expect(paused and not controller._resume_button.disabled, "Volver a horizontal debe permitir continuar sin reanudar por sorpresa.")
	controller.resume_combat()
	controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(3)
	_expect(paused, "Cambiar de app debe pausar el combate.")
	controller.return_to_menu()
	await _frames(5)
	_expect(not paused and current_scene.get_node_or_null("Player") == null, "Volver al inicio debe liberar la pausa y sacar el combate.")
	menu = current_scene
	menu.start_practice()
	await _frames(5)
	_expect(current_scene.get_node_or_null("TrainingDummy") != null and current_scene.get_node_or_null("Opponent") == null, "El inicio también debe abrir práctica.")
	current_scene.queue_free()
	await process_frame
	print("MOBILE_APP_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
