extends Control

const ViewportLayout = preload("res://scripts/ui/mobile_viewport.gd")
var _title: Label
var _subtitle: Label
var _tag: Label
var _actions: VBoxContainer
var _update: Button
var _leaving: bool = false

func _ready() -> void:
	_title = _label("BOXEO", 80, Color("f6be64"))
	_tag = _label("PROTOTIPO DE COMBATE", 18, Color("8de8cc"))
	_subtitle = _label("Medí la distancia.\nElegí el momento.", 28, Color("ced8e4"))
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 16)
	add_child(_actions)
	_button("ENTRAR AL RING", Color("f6be64"), start_sparring)
	_button("PRÁCTICA CON MUÑECO", Color("8de8cc"), start_practice)
	if OS.has_feature("web"):
		var standalone: bool = bool(JavaScriptBridge.eval("window.BoxingWeb && window.BoxingWeb.isStandalone()"))
		if not standalone:
			_button("INSTALAR EN IPHONE", Color("7bafff"), _show_install)
		_update = _button("ACTUALIZAR JUEGO", Color("f6be64"), _apply_update)
		_update.visible = JavaScriptBridge.pwa_needs_update()
		JavaScriptBridge.pwa_update_available.connect(_show_update)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _button(title: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0, 82)
	button.add_theme_font_size_override("font_size", 23)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172333")
	style.border_color = color
	style.set_border_width_all(3)
	style.set_content_margin_all(14)
	button.add_theme_stylebox_override("normal", style)
	var highlighted := style.duplicate() as StyleBoxFlat
	highlighted.bg_color = Color("293c50")
	button.add_theme_stylebox_override("hover", highlighted)
	button.add_theme_stylebox_override("pressed", highlighted)
	button.pressed.connect(action)
	_actions.add_child(button)
	return button

func _layout() -> void:
	var area: Rect2 = ViewportLayout.safe_rect(get_viewport_rect().size)
	var inset: float = maxf(40.0, area.size.x * 0.06)
	_tag.position = area.position + Vector2(inset, area.size.y * 0.29)
	_title.position = _tag.position + Vector2(-4, 34)
	_subtitle.position = _title.position + Vector2(4, 115)
	_actions.size.x = minf(500.0, area.size.x * 0.43)
	_actions.position = Vector2(area.end.x - inset - _actions.size.x, area.position.y + area.size.y * 0.5 - 158)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101923"))
	for x in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.35, 0.45, 0.12))
	draw_line(Vector2(0, size.y - 30), Vector2(size.x, size.y - 30), Color("f6be64"), 3)

func start_sparring() -> void:
	_start("res://scenes/sparring.tscn")

func start_practice() -> void:
	_start("res://scenes/combat_test.tscn")

func _start(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	_open_scene.call_deferred(path)

func _open_scene(path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		_leaving = false
		push_error("No se pudo abrir el modo de juego: " + error_string(error))

func _show_install() -> void:
	JavaScriptBridge.eval("window.BoxingWeb && window.BoxingWeb.showInstall()")

func _show_update() -> void:
	_update.show()

func _apply_update() -> void:
	JavaScriptBridge.pwa_update()
