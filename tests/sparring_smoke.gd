extends SceneTree

var _failures: int = 0
var _enemy_attacks: int = 0
var _states: Array[int] = []

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
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	var player = scene.get_node("Player")
	var opponent = scene.get_node("Opponent")
	opponent._random.seed = 47
	opponent.punch_started.connect(func(_direction: Vector2): _enemy_attacks += 1)
	var initial_distance: float = player.position.distance_to(opponent.position)
	for index in 36:
		await _frames(10)
		if not _states.has(opponent.brain_state):
			_states.append(opponent.brain_state)
		_expect(scene.ring_rect.has_point(opponent.position), "El rival debe permanecer dentro del ring.")
	_expect(player.position.distance_to(opponent.position) < initial_distance - 70.0, "El rival debe acercarse hasta distancia de ataque.")
	_expect(_enemy_attacks > 0 and player.health.current_health < 500.0, "El rival debe lanzar jabs y lastimar al jugador.")
	_expect(is_equal_approx(opponent.health.current_health, 500.0), "El rival no debe dañarse a sí mismo.")
	_expect(_states.has(opponent.BrainState.TELEGRAPH), "Debe mostrar una preparación antes de atacar.")

	# El rival no lee los controles humanos.
	opponent.brain_enabled = false
	opponent.stop_combat()
	var enemy_position: Vector2 = opponent.position
	Input.action_press("move_down")
	Input.action_press("block")
	Input.action_press("punch")
	await _frames(3)
	_expect(opponent.position == enemy_position and not opponent.is_blocking and opponent.attack_state == opponent.AttackState.IDLE, "Los controles del jugador no deben controlar al rival.")
	Input.action_release("move_down")
	Input.action_release("block")
	Input.action_release("punch")
	await _frames(8)

	# Un jab real frontal se reduce al 25 % y consume estamina de defensa.
	player.position = scene.ring_rect.get_center() - Vector2(28, 0)
	opponent.position = scene.ring_rect.get_center() + Vector2(28, 0)
	player.health.reset()
	player.stamina = 300.0
	player.stamina_regen = 0.0
	player.set_touch_block(true)
	await _frames(3)
	_expect(opponent.request_jab(), "El rival debe usar la misma API de ataques.")
	await _frames(8)
	var effects: Array = scene.get_node("ImpactEffects")._effects
	_expect(not effects.is_empty() and effects.back()["blocked"], "La guardia debe activar el efecto de bloqueo.")
	await _frames(22)
	_expect(is_equal_approx(player.health.current_health, 498.5), "La guardia frontal debe reducir un jab de 6 a 1,5.")
	_expect(is_equal_approx(player.stamina, 295.2), "Bloquear el jab debe gastar 4,8 de estamina.")
	_expect(is_equal_approx(scene.get_node("HUD/PlayerHealth").value, 498.5), "La vida visible debe reflejar el daño recibido.")

	# La guardia solo cubre el frente y puede romperse si falta energía.
	player.receive_attack(6.0, Vector2.RIGHT, 3.5, 0.03)
	_expect(is_equal_approx(player.health.current_health, 492.5), "Un golpe por detrás no debe quedar bloqueado.")
	player.stamina = 1.0
	player.receive_attack(6.0, Vector2.LEFT, 3.5, 0.03)
	_expect(is_zero_approx(player.stamina) and player._guard_break_left > 0.0, "La guardia debe romperse cuando falta estamina.")
	_expect(is_equal_approx(player.health.current_health, 486.5), "Romper la guardia debe dejar pasar el golpe completo.")
	player.set_touch_block(false)

	# Al agotarse, el rival se retira y descansa antes de volver a atacar.
	player.position = scene.ring_rect.get_center() - Vector2(130, 0)
	opponent.position = scene.ring_rect.get_center() + Vector2(100, 0)
	opponent.stamina = 0.0
	opponent.brain_enabled = true
	opponent._decision_left = 0.0
	opponent._telegraph_left = 0.0
	opponent._set_brain_state(opponent.BrainState.MEASURE)
	var before: int = _enemy_attacks
	await _frames(30)
	_expect(opponent.brain_state == opponent.BrainState.REST and _enemy_attacks == before, "Sin estamina debe descansar en vez de atacar gratis.")
	await _frames(240)
	_expect(opponent.stamina >= 60.0 and not opponent._resting, "Debe regenerar suficiente energía antes de retomar la pelea.")

	# La preparación permite salir de alcance antes del jab.
	opponent.stop_combat()
	player.position = scene.ring_rect.get_center() - Vector2(32, 0)
	opponent.position = scene.ring_rect.get_center() + Vector2(32, 0)
	opponent._cooldown_left = 0.0
	opponent._decision_left = 0.0
	opponent._set_brain_state(opponent.BrainState.MEASURE)
	for index in 30:
		if opponent.brain_state == opponent.BrainState.TELEGRAPH:
			break
		await _frames(1)
	_expect(opponent.brain_state == opponent.BrainState.TELEGRAPH, "El rival debe preparar el golpe antes de probar la retirada.")
	var life_before_escape: float = player.health.current_health
	player.set_touch_direction(Vector2.LEFT)
	await _frames(15)
	_expect(is_equal_approx(player.health.current_health, life_before_escape), "Salir de alcance durante la preparación debe evitar el impacto, aunque el rival llegue a lanzar al aire.")
	player.set_touch_direction(Vector2.ZERO)

	# Victoria y derrota detienen las acciones, incluso si quedan entradas pendientes.
	scene._player_round_wins = 1
	opponent.health.apply_damage(9999.0)
	_expect(scene._fight_finished and not player.combat_enabled and not opponent.combat_enabled, "Derrotar al rival debe terminar el sparring.")
	_expect(not player.request_jab() and not opponent.request_jab(), "No deben seguir atacando después del resultado.")
	before = _enemy_attacks
	await _frames(90)
	_expect(_enemy_attacks == before, "La IA debe permanecer detenida al terminar.")
	scene.queue_free()
	await process_frame
	var second_scene: Node = load("res://scenes/sparring.tscn").instantiate()
	root.add_child(second_scene)
	current_scene = second_scene
	await _frames(3)
	second_scene._rival_round_wins = 1
	second_scene.get_node("Player/Health").apply_damage(9999.0)
	_expect(second_scene._fight_finished and second_scene.get_node("HUD/Feedback").text.contains("perdiste"), "La derrota del jugador debe mostrar resultado y detener la pelea.")
	second_scene.queue_free()
	await process_frame
	print("SPARRING_SMOKE: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
