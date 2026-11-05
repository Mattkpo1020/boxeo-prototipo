extends Node2D

const EFFECT_LIFETIME: float = 0.18
const MAX_EFFECTS: int = 12
var _effects: Array[Dictionary] = []
var _swing_sound := AudioStreamPlayer.new()
var _hit_sound := AudioStreamPlayer.new()
var _block_sound := AudioStreamPlayer.new()

func _ready() -> void:
	# Dos sonidos sintetizados una sola vez; sin descargas ni recursos externos.
	_swing_sound.stream = _make_sound(false)
	_swing_sound.volume_db = -20.0
	_hit_sound.stream = _make_sound(true)
	_hit_sound.volume_db = -12.0
	_hit_sound.max_polyphony = 3
	add_child(_swing_sound)
	add_child(_hit_sound)
	_block_sound.stream = _hit_sound.stream
	_block_sound.volume_db = -19.0
	_block_sound.pitch_scale = 1.5
	add_child(_block_sound)
	set_process(false)

func play_swing(attack: BoxingAttack) -> void:
	_swing_sound.pitch_scale = 1.12 if attack.glove_side == 1 else 0.86
	_swing_sound.play()

func play_impact(point: Vector2, direction: Vector2, attack: BoxingAttack, blocked: bool) -> void:
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	_effects.append({"point": point, "direction": direction, "age": 0.0, "strong": attack.glove_side == -1, "blocked": blocked})
	if blocked:
		_block_sound.play()
	else:
		_hit_sound.pitch_scale = 1.05 if attack.glove_side == 1 else 0.78
		_hit_sound.play()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index]["age"] += delta
		if _effects[index]["age"] >= EFFECT_LIFETIME:
			_effects.remove_at(index)
	if _effects.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for effect: Dictionary in _effects:
		var age: float = effect["age"]
		var progress: float = age / EFFECT_LIFETIME
		var point: Vector2 = effect["point"]
		var direction: Vector2 = effect["direction"]
		var strong: bool = effect["strong"]
		if effect["blocked"]:
			var blue := Color("7bafff")
			blue.a = 1.0 - progress
			var angle: float = direction.angle() + PI
			draw_arc(point, 7.0 + progress * 14.0, angle - 1.0, angle + 1.0, 12, blue, 3.0, true)
			continue
		var color := Color("fff3ae") if not strong else Color("ffbd69")
		color.a = 1.0 - progress
		var damage_ring := Color("ff695e")
		damage_ring.a = 1.0 - progress
		draw_arc(point + direction * 12.0, 19.0 + progress * 15.0, 0.0, TAU, 24, damage_ring, 3.0, true)
		if age < 0.055:
			draw_rect(Rect2(point.round() - Vector2(9, 2), Vector2(18, 4)), Color.WHITE)
			draw_rect(Rect2(point.round() - Vector2(2, 9), Vector2(4, 18)), Color.WHITE)
		for spark in 6:
			var angle: float = (float(spark) / 5.0 - 0.5) * 3.2
			var distance: float = 5.0 + progress * (30.0 if strong else 21.0)
			var position_on_ring: Vector2 = point + direction.rotated(angle) * distance
			var pixel_size: float = 4.0 if spark % 2 == 0 else 2.0
			draw_rect(Rect2(position_on_ring.round(), Vector2.ONE * pixel_size), color)

func _make_sound(impact: bool) -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.13 if impact else 0.09
	var count: int = int(duration * rate)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 73 if impact else 29
	var phase: float = 0.0
	var filtered_noise: float = 0.0
	for index in count:
		var time: float = float(index) / rate
		var progress: float = float(index) / count
		var noise: float = random.randf_range(-1.0, 1.0)
		filtered_noise = lerpf(filtered_noise, noise, 0.4)
		var sample: float
		if impact:
			phase += TAU * lerpf(155.0, 55.0, progress) / rate
			sample = sin(phase) * exp(-time * 35.0) * 0.65
			sample += noise * exp(-time * 90.0) * 0.28
		else:
			sample = filtered_noise * sin(progress * PI) * (1.0 - progress) * 0.65
		# Ataque suave de 1 ms y final en cero para evitar chasquidos digitales.
		sample *= minf(1.0, time * 1000.0) * minf(1.0, (duration - time) * 1000.0)
		pcm.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = pcm
	return sound
