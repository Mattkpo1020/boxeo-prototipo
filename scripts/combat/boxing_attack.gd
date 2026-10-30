class_name BoxingAttack
extends Resource

@export var attack_id: StringName = &"jab"
var charge_ratio: float = 0.0

@export_range(1.0, 100.0) var damage: float = 10.0
@export_range(1.0, 100.0) var stamina_cost: float = 15.0
@export_range(0.02, 2.0) var windup: float = 0.12
@export_range(0.02, 2.0) var active: float = 0.10
@export_range(0.02, 2.0) var recovery: float = 0.22
@export_range(20.0, 100.0) var reach: float = 38.0
@export_range(1.0, 30.0) var radius: float = 9.0
@export_range(0.0, 0.1) var impact_pause: float = 0.04
@export_range(0.0, 15.0) var visual_recoil: float = 5.0
@export_range(0.0, 300.0) var knockback_speed: float = 0.0
@export_range(0.0, 0.15) var alternate_recovery_credit: float = 0.0
# Vector2.orthogonal() señala la izquierda del boxeador en coordenadas 2D.
@export_enum("Izquierda:1", "Derecha:-1") var glove_side: int = 1

func get_knockback_speed(hit_damage: float) -> float:
	# El bonus de combo escala suavemente el empuje, independientemente
	# de cuánta vida le quedaba al objetivo antes del golpe.
	return knockback_speed * sqrt(clampf(hit_damage / maxf(damage, 0.001), 0.0, 1.5))
