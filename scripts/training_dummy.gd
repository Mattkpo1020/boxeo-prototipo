extends StaticBody2D

@onready var health: HealthComponent = $Health
var _flash_left: float = 0.0
var _visual_offset := Vector2.ZERO
var _impact_pause_left: float = 0.0

func _ready() -> void:
	set_process(false)
	health.health_changed.connect(_on_health_changed)
	$Hurtbox.impact_received.connect(_on_impact_received)

func _on_impact_received(direction: Vector2, recoil: float, pause: float) -> void:
	_flash_left = 0.12
	_visual_offset = direction.normalized() * recoil
	_impact_pause_left = pause
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if _flash_left <= 0.0 and _visual_offset.is_zero_approx():
		set_process(false)
		return
	if _impact_pause_left > 0.0:
		_impact_pause_left = maxf(0.0, _impact_pause_left - delta)
		return
	_flash_left = maxf(0.0, _flash_left - delta)
	_visual_offset = _visual_offset.move_toward(Vector2.ZERO, 65.0 * delta)
	queue_redraw()
	if _flash_left <= 0.0 and _visual_offset.is_zero_approx():
		set_process(false)

func _on_health_changed(_current: float, _maximum: float) -> void:
	if _current >= _maximum:
		_flash_left = 0.0
		_visual_offset = Vector2.ZERO
		_impact_pause_left = 0.0
		set_process(false)
	queue_redraw()

func _draw() -> void:
	var color := Color("f6be64")
	if is_instance_valid(health) and health.current_health <= 0.0:
		color = Color("687384")
	elif _flash_left > 0.0:
		color = Color.WHITE
	draw_circle(Vector2(0, 5), 24.0, Color(0, 0, 0, 0.3))
	draw_set_transform(_visual_offset)
	draw_circle(Vector2.ZERO, 20.0, color)
	draw_line(Vector2(-9, 0), Vector2(9, 0), Color("21344a"), 3.0)
	draw_line(Vector2(0, -9), Vector2(0, 9), Color("21344a"), 3.0)
	draw_set_transform(Vector2.ZERO)
