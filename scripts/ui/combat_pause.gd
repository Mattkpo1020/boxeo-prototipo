extends CanvasLayer

const ViewportLayout = preload("res://scripts/ui/mobile_viewport.gd")
var _overlay: ColorRect
var _panel: VBoxContainer
var _heading: Label
var _pause_button: Button
var _resume_button: Button
var _browser_callback: JavaScriptObject
var _paused: bool = false

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_button = Button.new()
	_pause_button.text = "PAUSA"
	_pause_button.add_theme_font_size_override("font_size", 16)
	_pause_button.pressed.connect(pause_combat)
	add_child(_pause_button)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.025, 0.04, 0.065, 0.96)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 18)
	_overlay.add_child(_panel)
	_heading = Label.new()
	_heading.text = "COMBATE EN PAUSA"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 30)
	_panel.add_child(_heading)
	_resume_button = _button("CONTINUAR", resume_combat)
	_button("VOLVER AL INICIO", return_to_menu)
	_overlay.hide()
	get_viewport().size_changed.connect(_layout)
	if OS.has_feature("web"):
		_browser_callback = JavaScriptBridge.create_callback(_on_browser_hidden)
		var bridge := JavaScriptBridge.get_interface("BoxingWeb")
		if bridge != null:
			bridge.setPauseHandler(_browser_callback)
	_layout()

func _button(title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0, 86)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	_panel.add_child(button)
	return button

func _layout() -> void:
	var area: Rect2 = ViewportLayout.safe_rect(get_viewport().get_visible_rect().size)
	_pause_button.position = Vector2(area.get_center().x - 60, area.position.y + 42)
	_pause_button.size = Vector2(120, 82)
	_panel.size.x = minf(520.0, area.size.x - 64.0)
	_panel.position = area.get_center() - Vector2(_panel.size.x * 0.5, 140)
	if area.size.y > area.size.x:
		pause_combat()
	_resume_button.disabled = area.size.y > area.size.x

func pause_combat() -> void:
	if _paused:
		return
	_paused = true
	get_parent().release_combat_inputs()
	_overlay.show()
	get_tree().paused = true

func resume_combat() -> void:
	if _resume_button.disabled:
		return
	get_parent().release_combat_inputs()
	_paused = false
	_overlay.hide()
	get_tree().paused = false

func return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")

func _on_browser_hidden(arguments: Array) -> void:
	if not arguments.is_empty() and bool(arguments[0]):
		pause_combat.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if _paused:
			resume_combat()
		else:
			pause_combat()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if is_node_ready() and (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT):
		pause_combat.call_deferred()

func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BoxingWeb && window.BoxingWeb.setPauseHandler(null)")
	_browser_callback = null
	get_tree().paused = false
