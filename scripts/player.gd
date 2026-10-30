extends "res://scripts/fighters/fighter_body.gd"

# Solo el jugador lee entradas humanas; las reglas viven en FighterBody.
func _get_move_direction() -> Vector2:
	if not _touch_direction.is_zero_approx():
		return _touch_direction
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _is_block_held() -> bool:
	return super._is_block_held() or Input.is_action_pressed("block")

func _is_cross_held() -> bool:
	return super._is_cross_held() or Input.is_action_pressed("cross")

func _is_sprint_held() -> bool:
	return Input.is_action_pressed("sprint")

func _poll_attack_input() -> void:
	if Input.is_action_just_pressed("dodge"):
		request_dodge()
	if Input.is_action_just_pressed("punch"):
		request_jab()
	super._poll_attack_input()
