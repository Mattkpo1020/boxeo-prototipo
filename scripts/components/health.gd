class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal recoverable_changed(amount: float)
signal health_recovered(amount: float)
signal defeated

@export_range(1.0, 1000.0) var max_health: float = 100.0
@export_group("Vida recuperable")
@export_range(0.0, 1.0) var recoverable_fraction: float = 0.6
@export_range(0.0, 5.0) var recovery_decay_delay: float = 1.0
@export_range(0.0, 100.0) var recovery_decay_per_second: float = 12.0
@export_range(0.0, 1.0) var damage_to_healing_ratio: float = 0.5
var current_health: float = 0.0
var recoverable_health: float = 0.0
var recovery_active: bool = true
var _decay_delay_left: float = 0.0

func _ready() -> void:
	reset()

func apply_damage(amount: float, refresh_recovery_delay: bool = true) -> bool:
	if amount <= 0.0 or current_health <= 0.0:
		return false
	var actual_damage: float = minf(amount, current_health)
	current_health -= actual_damage
	if current_health > 0.0 and recovery_active:
		if refresh_recovery_delay or recoverable_health <= 0.0:
			_decay_delay_left = recovery_decay_delay
		recoverable_health = minf(max_health - current_health, recoverable_health + actual_damage * recoverable_fraction)
	else:
		recoverable_health = 0.0 # Una derrota no puede revertirse con recuperación.
	health_changed.emit(current_health, max_health)
	recoverable_changed.emit(recoverable_health)
	if current_health <= 0.0:
		defeated.emit()
	return true

func _physics_process(delta: float) -> void:
	advance_recovery(delta)

func advance_recovery(delta: float) -> void:
	if not recovery_active or current_health <= 0.0 or recoverable_health <= 0.0 or delta <= 0.0:
		return
	var decay_time: float = delta
	if _decay_delay_left > 0.0:
		var grace_time: float = minf(_decay_delay_left, delta)
		_decay_delay_left -= grace_time
		decay_time -= grace_time
	if decay_time <= 0.0 or recovery_decay_per_second <= 0.0:
		return
	# Se pierde la oportunidad de recuperar, no más vida real.
	recoverable_health = maxf(0.0, recoverable_health - recovery_decay_per_second * decay_time)
	recoverable_changed.emit(recoverable_health)

func restore_from_damage(actual_damage_dealt: float) -> float:
	if not recovery_active or current_health <= 0.0 or recoverable_health <= 0.0 or actual_damage_dealt <= 0.0:
		return 0.0
	var restored: float = minf(recoverable_health, actual_damage_dealt * damage_to_healing_ratio)
	restored = minf(restored, maxf(0.0, max_health - current_health))
	if restored <= 0.0:
		return 0.0
	current_health += restored
	recoverable_health -= restored
	health_changed.emit(current_health, max_health)
	recoverable_changed.emit(recoverable_health)
	health_recovered.emit(restored)
	return restored

func reset() -> void:
	current_health = max_health
	recoverable_health = 0.0
	_decay_delay_left = 0.0
	recovery_active = true
	health_changed.emit(current_health, max_health)
	recoverable_changed.emit(recoverable_health)
