extends Control

signal movement_changed(direction: Vector2)
signal jab_requested
signal cross_changed(held: bool, canceled: bool)
signal block_changed(held: bool)
signal dodge_requested

const NO_POINTER: int = -2
const DEAD_ZONE: float = 0.15
var joystick_center := Vector2.ZERO
var joystick_radius: float = 90.0
var button_radius: float = 48.0
var button_centers: Dictionary = {}
var _joystick_pointer: int = NO_POINTER
var _stick := Vector2.ZERO
var _pointers: Dictionary = {}
var _font: Font = ThemeDB.fallback_font
var _charge_ratio: float = 0.0
var _charging: bool = false
var _dodge_cooldown_ratio: float = 0.0

func set_dodge_cooldown(remaining: float, total: float) -> void:
	_dodge_cooldown_ratio = clampf(remaining / maxf(total, 0.001), 0.0, 1.0)
	queue_redraw()

func set_cross_charge(ratio: float, charging: bool) -> void:
	_charge_ratio = clampf(ratio, 0.0, 1.0)
	_charging = charging
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure_layout(ring: Rect2, viewport_size: Vector2, safe_area: Rect2 = Rect2()) -> void:
	release_all()
	if not safe_area.has_area():
		safe_area = Rect2(Vector2.ZERO, viewport_size)
	var side_width: float = ring.position.x - safe_area.position.x
	var control_scale: float = clampf(side_width / 340.0, 0.55, 1.0)
	joystick_radius = 90.0 * control_scale
	button_radius = 48.0 * control_scale
	joystick_center = safe_area.position + Vector2(side_width * 0.5, safe_area.size.y * 0.61)
	var right_center := safe_area.position + Vector2(safe_area.size.x - side_width * 0.5, safe_area.size.y * 0.55)
	button_centers = {
		&"jab": right_center + Vector2(-55, -60) * control_scale,
		&"cross": right_center + Vector2(55, -60) * control_scale,
		&"dodge": right_center + Vector2(-55, 60) * control_scale,
		&"block": right_center + Vector2(55, 60) * control_scale,
	}
	queue_redraw()

func _input(event: InputEvent) -> void:
	# La emulación permite usar menús Button con touch. Los controles del
	# combate ya leen dedos reales: ignorar aquí su copia de ratón.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_press(event.index, event.position)
		else:
			_release(event.index, event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(-1, event.position)
		else:
			_release(-1)
	elif event is InputEventMouseMotion and _pointers.has(-1):
		_drag(-1, event.position)

func _press(pointer: int, position_on_screen: Vector2) -> void:
	if _pointers.has(pointer):
		return
	if _joystick_pointer == NO_POINTER and position_on_screen.distance_to(joystick_center) <= joystick_radius:
		_joystick_pointer = pointer
		_pointers[pointer] = &"move"
		_update_stick(position_on_screen)
		return
	for action: StringName in button_centers:
		if position_on_screen.distance_to(button_centers[action]) > button_radius:
			continue
		_pointers[pointer] = action
		match action:
			&"jab": jab_requested.emit()
			&"dodge": dodge_requested.emit()
			&"cross":
				if _pointers.values().count(&"cross") == 1:
					cross_changed.emit(true, false)
			&"block": block_changed.emit(true)
		queue_redraw()
		return

func _drag(pointer: int, position_on_screen: Vector2) -> void:
	if pointer == _joystick_pointer:
		_update_stick(position_on_screen)
	elif _pointers.has(pointer):
		var action: StringName = _pointers[pointer]
		if position_on_screen.distance_to(button_centers[action]) > button_radius * 1.25:
			_release(pointer, true)

func _release(pointer: int, canceled: bool = false) -> void:
	if not _pointers.has(pointer):
		return
	var action: StringName = _pointers[pointer]
	_pointers.erase(pointer)
	if pointer == _joystick_pointer:
		_joystick_pointer = NO_POINTER
		_stick = Vector2.ZERO
		movement_changed.emit(Vector2.ZERO)
	elif action == &"block" and not _pointers.values().has(&"block"):
		block_changed.emit(false)
	elif action == &"cross" and not _pointers.values().has(&"cross"):
		cross_changed.emit(false, canceled)
	queue_redraw()

func _update_stick(position_on_screen: Vector2) -> void:
	_stick = ((position_on_screen - joystick_center) / joystick_radius).limit_length(1.0)
	var strength: float = _stick.length()
	var direction := Vector2.ZERO
	if strength > DEAD_ZONE:
		direction = _stick.normalized() * ((strength - DEAD_ZONE) / (1.0 - DEAD_ZONE))
	movement_changed.emit(direction)
	queue_redraw()

func release_all() -> void:
	_pointers.clear()
	_joystick_pointer = NO_POINTER
	_stick = Vector2.ZERO
	movement_changed.emit(Vector2.ZERO)
	block_changed.emit(false)
	cross_changed.emit(false, true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()

func _draw() -> void:
	if button_centers.is_empty():
		return
	draw_circle(joystick_center, joystick_radius, Color("172333"))
	draw_arc(joystick_center, joystick_radius, 0, TAU, 64, Color("64788e"), 2.0, true)
	draw_circle(joystick_center + _stick * joystick_radius * 0.65, joystick_radius * 0.36, Color("4fd1b0"))
	_draw_text("MOVER", joystick_center + Vector2(0, joystick_radius + 32), 18, Color("a8b8cc"))
	for action: StringName in button_centers:
		var center: Vector2 = button_centers[action]
		var color := Color("ff786d")
		if action == &"cross":
			color = Color("f6be64")
		elif action == &"block":
			color = Color("7bafff")
		elif action == &"dodge":
			color = Color("64788e") if _dodge_cooldown_ratio > 0.0 else Color("8de8cc")
		var held: bool = _pointers.values().has(action)
		draw_circle(center, button_radius, color.darkened(0.25) if held else Color("172333"))
		draw_arc(center, button_radius, 0, TAU, 48, color, 3.0, true)
		if action == &"dodge" and _dodge_cooldown_ratio > 0.0:
			draw_arc(center, button_radius - 5, -PI * 0.5, -PI * 0.5 + TAU * _dodge_cooldown_ratio, 48, Color("8de8cc"), 2.0, true)
		if action == &"cross" and _charging:
			draw_arc(center, button_radius + 7, -PI * 0.5, -PI * 0.5 + TAU * maxf(_charge_ratio, 0.001), 48, Color("fff3ae"), 4.0, true)
		var font_size: int = clampi(roundi(button_radius * 0.4), 12, 19)
		if action == &"jab" or action == &"cross":
			_draw_text(String(action).to_upper(), center + Vector2(0, 1), font_size, Color.WHITE)
			var hand: String = "IZQ." if action == &"jab" else "DER."
			if action == &"cross" and _charging:
				hand = "%d%%" % roundi(_charge_ratio * 100.0)
			_draw_text(hand, center + Vector2(0, button_radius * 0.48), font_size - 3, color)
		else:
			var title: String = "ESQ." if action == &"dodge" else String(action).to_upper()
			_draw_text(title, center + Vector2(0, 7), font_size, Color.WHITE)

func _draw_text(text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	var text_width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, baseline_center - Vector2(text_width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
