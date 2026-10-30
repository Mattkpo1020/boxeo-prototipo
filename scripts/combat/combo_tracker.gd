class_name ComboTracker
extends RefCounted

var _definitions: Array[BoxingCombo] = []
var _hits: Array[StringName] = []
var _target_id: int = 0
var _time_left: float = 0.0
var _window: float = 0.85
var _maximum_length: int = 3

func configure(definitions: Array[BoxingCombo], window: float) -> void:
	_definitions = definitions
	_window = window
	for definition: BoxingCombo in definitions:
		_maximum_length = maxi(_maximum_length, definition.sequence.size())
	reset()

func advance(delta: float) -> void:
	_time_left = maxf(0.0, _time_left - delta)
	if _time_left <= 0.0:
		reset()

func reset() -> void:
	_hits.clear()
	_target_id = 0
	_time_left = 0.0

# Predice el bonus sin consumirlo: solo se confirma si se acepta el impacto.
func preview(attack_id: StringName, target_id: int) -> BoxingCombo:
	if _target_id != target_id or _time_left <= 0.0:
		return null
	var candidate: Array[StringName] = _hits.duplicate()
	candidate.append(attack_id)
	var best: BoxingCombo
	for definition: BoxingCombo in _definitions:
		var length: int = definition.sequence.size()
		if length < 2 or candidate.size() < length:
			continue
		var matches: bool = true
		for index in length:
			if candidate[candidate.size() - length + index] != definition.sequence[index]:
				matches = false
				break
		if matches and (best == null or length > best.sequence.size()):
			best = definition
	return best

func record_clean_hit(attack_id: StringName, target_id: int) -> BoxingCombo:
	var completed: BoxingCombo = preview(attack_id, target_id)
	if completed != null:
		# El remate pertenece a un solo combo: no encadena bonus superpuestos.
		reset()
		return completed
	if _target_id != target_id or _time_left <= 0.0:
		reset()
	_hits.append(attack_id)
	while _hits.size() >= _maximum_length:
		_hits.pop_front()
	_target_id = target_id
	_time_left = _window
	return null
