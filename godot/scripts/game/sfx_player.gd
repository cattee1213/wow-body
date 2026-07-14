class_name SfxPlayer
extends Node
## Lightweight one-shot SFX for the three spells.
## Loads PCM WAV via FileAccess so it works even before Godot reimports assets.

const PATHS := {
	GameBus.SPELL_FIRE: "res://assets/sfx/fire_hit.wav",
	GameBus.SPELL_FROST: "res://assets/sfx/frost_hit.wav",
	GameBus.ULT_FIRESTORM: "res://assets/sfx/fire_hit.wav",
	GameBus.ULT_BLIZZARD: "res://assets/sfx/frost_hit.wav",
}

var _streams: Dictionary = {} # StringName -> AudioStream
var _players: Array = [] # AudioStreamPlayer
var _idx: int = 0
const POOL := 6


func _ready() -> void:
	for spell in PATHS.keys():
		var path: String = PATHS[spell]
		var stream := _load_stream(path)
		if stream:
			_streams[spell] = stream
		else:
			push_warning("SfxPlayer: missing %s" % path)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		p.volume_db = -3.0
		add_child(p)
		_players.append(p)


func play_spell(spell: StringName, pitch_jitter: float = 0.08) -> void:
	var stream: AudioStream = _streams.get(spell, null)
	if stream == null:
		return
	var p: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return _load_wav_pcm(path)


func _load_wav_pcm(path: String) -> AudioStreamWAV:
	## Minimal PCM16 mono/stereo WAV reader.
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var riff := f.get_buffer(4).get_string_from_ascii()
	if riff != "RIFF":
		return null
	f.get_32() # file size
	var wave := f.get_buffer(4).get_string_from_ascii()
	if wave != "WAVE":
		return null

	var audio_format := 1
	var channels := 1
	var sample_rate := 22050
	var bits_per_sample := 16
	var data := PackedByteArray()

	while f.get_position() + 8 <= f.get_length():
		var chunk_id := f.get_buffer(4).get_string_from_ascii()
		var chunk_size := f.get_32()
		var chunk_end := f.get_position() + chunk_size
		if chunk_id == "fmt ":
			audio_format = f.get_16()
			channels = f.get_16()
			sample_rate = f.get_32()
			f.get_32() # byte rate
			f.get_16() # block align
			bits_per_sample = f.get_16()
		elif chunk_id == "data":
			data = f.get_buffer(chunk_size)
		f.seek(chunk_end)
		# WAV chunks are word-aligned
		if chunk_size % 2 == 1 and f.get_position() < f.get_length():
			f.get_8()

	if data.is_empty() or audio_format != 1 or bits_per_sample != 16:
		return null

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels > 1
	stream.data = data
	return stream
