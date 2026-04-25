extends Node2D
## Main controller — wires Guitar → AudioEngine → Visualizer → UI

@onready var guitar: Node2D     = $Guitar
@onready var visualizer: Node2D = $Visualizer
@onready var camera: Camera2D   = $Camera
@onready var ui: CanvasLayer    = $UI

func _ready() -> void:
	guitar.strummed.connect(_on_string_strummed)
	guitar.chord_strummed.connect(_on_chord_strummed)
	guitar.whammy_changed.connect(_on_whammy_changed)

	ui.distortion_changed.connect(func(v): AudioEngine.distortion = v)
	ui.reverb_changed.connect(func(v):     AudioEngine.reverb_amount = v)
	ui.delay_changed.connect(func(v):      AudioEngine.delay_amount = v)
	ui.volume_changed.connect(func(v):     AudioEngine.master_volume = v)
	ui.shred_mode_toggled.connect(func(a): Sequencer.set_shred_mode(a))

	Sequencer.note_triggered.connect(_on_sequencer_note)
	visualizer.guitar_position = guitar.global_position

func _on_string_strummed(string_idx: int, _frequency: float, velocity: float) -> void:
	visualizer.on_string_strummed(string_idx, velocity)
	_shake(velocity * 4.0)

func _on_chord_strummed(chord_name: String, _frequencies: Array) -> void:
	visualizer.on_chord_strummed(chord_name)
	ui.show_chord(chord_name)
	_shake(6.0)

func _on_whammy_changed(bend: float) -> void:
	visualizer.on_whammy(bend)

func _on_sequencer_note(string_idx: int, _frequency: float) -> void:
	guitar.strum_string_external(string_idx, 0.75)

func _shake(intensity: float) -> void:
	if intensity < 0.5:
		return
	var tween := create_tween()
	for i in range(6):
		tween.tween_property(camera, "offset",
			Vector2(randf_range(-intensity, intensity),
					randf_range(-intensity, intensity)), 0.04)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.06)
