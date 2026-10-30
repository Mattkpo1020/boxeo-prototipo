class_name CombatHurtbox
extends Area2D

signal impact_received(direction: Vector2, recoil: float, pause: float)

# Área que recibe golpes, independiente de la colisión física del cuerpo.
@export var health: HealthComponent
@export var defender: Node2D

func is_guarding(direction: Vector2) -> bool:
	return is_instance_valid(defender) and defender.has_method("is_guarding_direction") and defender.is_guarding_direction(direction)

func receive_hit(damage: float, direction: Vector2 = Vector2.ZERO, recoil: float = 0.0, pause: float = 0.0, knockback: float = 0.0) -> bool:
	if not is_instance_valid(health):
		return false
	var accepted: bool = false
	if is_instance_valid(defender) and defender.has_method("receive_attack"):
		accepted = defender.receive_attack(damage, direction, recoil, pause, knockback)
	else:
		accepted = health.apply_damage(damage)
	if not accepted:
		return false
	impact_received.emit(direction, recoil, pause)
	return true
