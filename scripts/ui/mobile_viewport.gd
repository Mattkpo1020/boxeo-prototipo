extends RefCounted

# Convierte los márgenes CSS del iPhone al espacio lógico del juego.
# En escritorio y en pruebas sin navegador usa todo el viewport.
static func safe_rect(viewport_size: Vector2) -> Rect2:
	var result := Rect2(Vector2.ZERO, viewport_size)
	if not OS.has_feature("web"):
		return result
	var raw = JavaScriptBridge.eval("window.BoxingWeb ? JSON.stringify(window.BoxingWeb.safeArea()) : null")
	if not raw is String:
		return result
	var data = JSON.parse_string(raw)
	if not data is Dictionary:
		return result
	var scale := viewport_size / Vector2(maxf(float(data.get("width", 1)), 1.0), maxf(float(data.get("height", 1)), 1.0))
	var leading := Vector2(float(data.get("left", 0)), float(data.get("top", 0))) * scale
	var trailing := Vector2(float(data.get("right", 0)), float(data.get("bottom", 0))) * scale
	result.position = leading
	result.size = (viewport_size - leading - trailing).max(Vector2.ONE)
	return result
