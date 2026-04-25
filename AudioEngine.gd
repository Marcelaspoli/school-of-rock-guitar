extends Node
## AudioEngine — AutoLoad singleton.
## Karplus-Strong plucked-string synthesis: far more realistic than sine/sawtooth.
## Each note owns a ring buffer seeded with noise; a one-pole low-pass filter
## running inside the buffer loop produces the natural harmonic decay of a string.

const SAMPLE_RATE := 44100
const BUFFER_LEN  := 0.05

var distortion:    float = 0.12
var reverb_amount: float = 0.42
var delay_amount:  float = 0.18
var master_volume: float = 0.80
var pitch_bend:    float = 0.0

class NoteState:
	var _buf:       PackedFloat32Array
	var _buf_len:   int
	var _read_pos:  float = 0.0
	var _write_pos: int   = 0
	var _last_out:  float = 0.0
	var _env:       float = 0.0
	var key_held:   bool  = true

	
	const DECAY_HELD  := 0.9993
	const DECAY_MUTED := 0.955

	func init(freq: float, sample_rate: int) -> void:
		_buf_len = max(4, int(round(float(sample_rate) / freq)))
		_buf     = PackedFloat32Array()
		_buf.resize(_buf_len)
		
		for i in range(_buf_len):
			_buf[i] = randf_range(-1.0, 1.0)
		for i in range(_buf_len):
			_buf[i] = (_buf[i] + _buf[(i + 1) % _buf_len]) * 0.5
		_read_pos  = 0.0
		_write_pos = 0

	func tick(pitch_factor: float) -> float:
		var decay: float = DECAY_HELD if key_held else DECAY_MUTED

		
		var ri   := int(_read_pos) % _buf_len
		var ri2  := (ri + 1) % _buf_len
		var frac := _read_pos - floorf(_read_pos)
		var out  := lerpf(_buf[ri], _buf[ri2], frac)

		
		_buf[_write_pos] = (out + _last_out) * 0.5 * decay
		_last_out = out

		_write_pos = (_write_pos + 1) % _buf_len
		_read_pos  = fmod(_read_pos + pitch_factor, float(_buf_len))

		_env = lerpf(_env, abs(out), 0.08)
		return out

	func is_silent() -> bool:
		return (not key_held) and _env < 0.0003

var _notes:    Dictionary = {}
var _player:   AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	_setup_bus()
	_setup_player()

func _setup_bus() -> void:
	var idx := AudioServer.get_bus_index("Guitar")
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Guitar")
		AudioServer.set_bus_send(idx, "Master")

	while AudioServer.get_bus_effect_count(idx) > 0:
		AudioServer.remove_bus_effect(idx, 0)

	
	var dist := AudioEffectDistortion.new()
	dist.mode      = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive     = distortion
	dist.pre_gain  = 4.0
	dist.post_gain = -2.0
	AudioServer.add_bus_effect(idx, dist)  # slot 0

	var rev := AudioEffectReverb.new()
	rev.room_size = 0.55
	rev.damping   = 0.70
	rev.wet       = reverb_amount
	rev.dry       = 1.0
	AudioServer.add_bus_effect(idx, rev)   # slot 1

	var dly := AudioEffectDelay.new()
	dly.tap1_active   = true
	dly.tap1_delay_ms = 310.0
	dly.tap1_level_db = lerp(-40.0, -9.0, delay_amount)
	dly.tap1_pan      = 0.28
	dly.tap2_active   = true
	dly.tap2_delay_ms = 620.0
	dly.tap2_level_db = lerp(-40.0, -18.0, delay_amount)
	dly.tap2_pan      = -0.28
	AudioServer.add_bus_effect(idx, dly)   # slot 2

func _setup_player() -> void:
	_player              = AudioStreamPlayer.new()
	add_child(_player)
	var stream           := AudioStreamGenerator.new()
	stream.mix_rate      = SAMPLE_RATE
	stream.buffer_length = BUFFER_LEN
	_player.stream       = stream
	_player.bus          = "Guitar"
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

func note_on(note_id: int, frequency: float) -> void:
	var n := NoteState.new()
	n.init(frequency, SAMPLE_RATE)
	_notes[note_id] = n

func note_off(note_id: int) -> void:
	if _notes.has(note_id):
		(_notes[note_id] as NoteState).key_held = false

func get_amplitude() -> float:
	var peak := 0.0
	for id in _notes:
		peak = max(peak, (_notes[id] as NoteState)._env)
	return clamp(peak, 0.0, 1.0)

func _process(_delta: float) -> void:
	_update_bus_effects()
	_fill_buffer()

func _fill_buffer() -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames == 0:
		return

	var to_purge  := []
	var pitch_fac := pow(2.0, pitch_bend / 12.0)

	for _f in range(frames):
		var sample := 0.0
		for id in _notes:
			var n: NoteState = _notes[id]
			if n.is_silent():
				if id not in to_purge:
					to_purge.append(id)
				continue
			sample += n.tick(pitch_fac)

		
		var count: int = maxi(1, _notes.size())
		sample = tanh(sample / count * (1.0 + distortion * 1.2)) * master_volume
		_playback.push_frame(Vector2(sample, sample))

	for id in to_purge:
		_notes.erase(id)

func _update_bus_effects() -> void:
	var idx := AudioServer.get_bus_index("Guitar")
	if idx < 0:
		return
	if AudioServer.get_bus_effect_count(idx) >= 1:
		var d := AudioServer.get_bus_effect(idx, 0) as AudioEffectDistortion
		if d:
			d.drive = distortion
	if AudioServer.get_bus_effect_count(idx) >= 2:
		var r := AudioServer.get_bus_effect(idx, 1) as AudioEffectReverb
		if r:
			r.wet = reverb_amount
	if AudioServer.get_bus_effect_count(idx) >= 3:
		var dl := AudioServer.get_bus_effect(idx, 2) as AudioEffectDelay
		if dl:
			dl.tap1_level_db = lerp(-40.0, -9.0,  delay_amount)
			dl.tap2_level_db = lerp(-40.0, -18.0, delay_amount)
