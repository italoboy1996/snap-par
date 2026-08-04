extends Node

var ambience_player: AudioStreamPlayer

func _ready() -> void:
	ambience_player = AudioStreamPlayer.new()
	ambience_player.stream = _make_tone(92.0, 2.0, 0.035, true)
	ambience_player.volume_db = -31.0
	add_child(ambience_player)

func start_ambience() -> void:
	if ambience_player and not ambience_player.playing:
		ambience_player.play()

func stop_ambience() -> void:
	if ambience_player:
		ambience_player.stop()

func play_shot() -> void:
	_play_one_shot(_make_tone(420.0, 0.06, 0.45), -10.0, 1.0)

func play_collision(material_name: String, impact_speed: float) -> void:
	if impact_speed < 45.0:
		return
	var frequency := 260.0
	match material_name:
		"sand": frequency = 105.0
		"ice": frequency = 880.0
	var strength := clampf(impact_speed / 850.0, 0.0, 1.0)
	_play_one_shot(_make_tone(frequency, 0.055, 0.35), lerpf(-25.0, -7.0, strength), lerpf(0.94, 1.08, strength))

func play_water() -> void:
	_play_one_shot(_make_noise(0.22, 0.34), -8.0, 0.8)

func play_hole() -> void:
	_play_one_shot(_make_tone(220.0, 0.09, 0.38), -9.0, 1.0)
	await get_tree().create_timer(0.075, true, false, true).timeout
	_play_one_shot(_make_tone(660.0, 0.12, 0.34), -8.0, 1.0)

func _play_one_shot(stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(func(): player.queue_free())
	player.play()

func _make_tone(frequency: float, duration: float, amplitude: float, looped := false) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := int(duration * mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var envelope := 1.0 if looped else pow(1.0 - float(i) / maxf(1.0, frames - 1.0), 2.0)
		var sample := int(sin(TAU * frequency * float(i) / mix_rate) * amplitude * envelope * 32767.0)
		bytes.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames
	return stream

func _make_noise(duration: float, amplitude: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := int(duration * mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91273
	var previous := 0.0
	for i in frames:
		var raw := rng.randf_range(-1.0, 1.0)
		previous = lerpf(previous, raw, 0.18)
		var envelope := pow(1.0 - float(i) / maxf(1.0, frames - 1.0), 1.5)
		bytes.encode_s16(i * 2, int(previous * amplitude * envelope * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.data = bytes
	return stream
