extends Node
## Sequencer — AutoLoad singleton.
## Powers SHRED MODE: fires random pentatonic-scale riffs at speed.

signal note_triggered(string_idx: int, frequency: float)


const PENTA_STRINGS: Array[int]   = [0, 0, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5]
const PENTA_OFFSETS: Array[float] = [
	1.0, 1.189, 1.335, 1.498, 1.682,  # E  G  A  B  D
	2.0, 2.378, 2.670, 2.997, 3.364,
	4.0, 4.757
]

var _active: bool = false
var _timer: Timer


var _interval: float = 0.12

func _ready() -> void:
	_timer          = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = _interval
	_timer.timeout.connect(_fire_note)
	add_child(_timer)

func set_shred_mode(on: bool) -> void:
	_active = on
	if on:
		_timer.start(_interval)
	else:
		_timer.stop()
		
		for i in range(6):
			AudioEngine.note_off(200 + i)

func set_speed(bpm: float) -> void:
	
	_interval          = 60.0 / max(bpm, 1.0)
	_timer.wait_time   = _interval
	if _active:
		_timer.start(_interval)

func _fire_note() -> void:
	if not _active:
		return

	var pick_idx := randi() % PENTA_STRINGS.size()
	var s_idx    := PENTA_STRINGS[pick_idx]
	var freq     := Guitar.STRING_FREQ[s_idx] * PENTA_OFFSETS[randi() % PENTA_OFFSETS.size()]
	freq          = clamp(freq, 60.0, 1200.0)

	
	AudioEngine.note_on(200 + s_idx, freq)
	note_triggered.emit(s_idx, freq)

	
	await get_tree().create_timer(_interval * 0.55).timeout
	AudioEngine.note_off(200 + s_idx)
