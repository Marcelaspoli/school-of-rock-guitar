extends CanvasLayer

signal distortion_changed(value: float)
signal reverb_changed(value: float)
signal delay_changed(value: float)
signal volume_changed(value: float)
signal shred_mode_toggled(active: bool)

const PANEL_X  := 900.0
const PANEL_Y  :=  30.0
const PANEL_W  := 350.0
const ROW_H    :=  52.0
const LABEL_W  := 130.0
const SLIDER_W := 180.0

var _chord_label:  Label
var _shred_btn:    Button
var _shred_active: bool = false

func _ready() -> void:
	_build_panel()
	_build_chord_display()
	_build_controls_hint()

func _build_panel() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.05, 0.0, 0.0, 0.88)
	bg.position = Vector2(PANEL_X - 12, PANEL_Y - 12)
	bg.size     = Vector2(PANEL_W + 16, ROW_H * 6 + 120)
	add_child(bg)

	var border := ColorRect.new()
	border.color    = Color(0.85, 0.05, 0.02, 0.9)
	border.position = bg.position
	border.size     = Vector2(PANEL_W + 16, 3)
	add_child(border)

	_build_title()
	_build_slider("Distortion", 0, 0.30, distortion_changed)
	_build_slider("Reverb",     1, 0.40, reverb_changed)
	_build_slider("Delay",      2, 0.30, delay_changed)
	_build_slider("Volume",     3, 0.80, volume_changed)
	_build_shred_button(4)

func _build_title() -> void:
	var lbl := Label.new()
	lbl.text     = "SCHOOL OF ROCK"
	lbl.position = Vector2(PANEL_X, PANEL_Y)
	lbl.add_theme_color_override("font_color",    Color(1.0, 0.12, 0.04))
	lbl.add_theme_font_size_override("font_size", 22)
	add_child(lbl)

func _build_slider(label_text: String, row: int,
		default_val: float, sig: Signal) -> void:
	var y := PANEL_Y + 38 + row * ROW_H

	var lbl := Label.new()
	lbl.text     = label_text.to_upper()
	lbl.position = Vector2(PANEL_X, y + 10)
	lbl.add_theme_color_override("font_color",    Color(0.9, 0.7, 0.65))
	lbl.add_theme_font_size_override("font_size", 13)
	add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text     = "%.0f%%" % (default_val * 100)
	val_lbl.position = Vector2(PANEL_X + SLIDER_W + LABEL_W + 4, y + 10)
	val_lbl.add_theme_color_override("font_color",    Color(1.0, 0.45, 0.05))
	val_lbl.add_theme_font_size_override("font_size", 13)
	add_child(val_lbl)

	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step      = 0.01
	sl.value     = default_val
	sl.position  = Vector2(PANEL_X + LABEL_W, y + 6)
	sl.size      = Vector2(SLIDER_W, 22)
	_style_slider(sl)
	add_child(sl)

	sl.value_changed.connect(func(v: float):
		val_lbl.text = "%.0f%%" % (v * 100)
		sig.emit(v)
	)

func _style_slider(sl: HSlider) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color             = Color(0.7, 0.08, 0.02)
	fill.content_margin_top    = 7
	fill.content_margin_bottom = 7

	var track := StyleBoxFlat.new()
	track.bg_color             = Color(0.15, 0.02, 0.01)
	track.content_margin_top    = 7
	track.content_margin_bottom = 7

	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("slider",       track)

func _build_shred_button(row: int) -> void:
	var y := PANEL_Y + 38 + row * ROW_H

	_shred_btn          = Button.new()
	_shred_btn.text     = "SHRED MODE"
	_shred_btn.position = Vector2(PANEL_X, y)
	_shred_btn.size     = Vector2(PANEL_W - 10, 38)
	_style_shred_btn(false)
	add_child(_shred_btn)

	_shred_btn.pressed.connect(_on_shred_pressed)

func _style_shred_btn(active: bool) -> void:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color                    = Color(0.65, 0.04, 0.02) if active else Color(0.18, 0.02, 0.01)
	sbox.border_color                = Color(1.0, 0.15, 0.04)
	sbox.border_width_left           = 2
	sbox.border_width_right          = 2
	sbox.border_width_top            = 2
	sbox.border_width_bottom         = 2
	sbox.corner_radius_top_left      = 6
	sbox.corner_radius_top_right     = 6
	sbox.corner_radius_bottom_left   = 6
	sbox.corner_radius_bottom_right  = 6
	_shred_btn.add_theme_stylebox_override("normal", sbox)
	_shred_btn.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.2) if active else Color(0.9, 0.5, 0.45))
	_shred_btn.add_theme_font_size_override("font_size", 16)

func _on_shred_pressed() -> void:
	_shred_active = not _shred_active
	_style_shred_btn(_shred_active)
	shred_mode_toggled.emit(_shred_active)

func _build_chord_display() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.04, 0.0, 0.0, 0.80)
	bg.position = Vector2(30, 30)
	bg.size     = Vector2(220, 90)
	add_child(bg)

	var title := Label.new()
	title.text     = "CHORD"
	title.position = Vector2(44, 38)
	title.add_theme_color_override("font_color",    Color(0.7, 0.3, 0.3))
	title.add_theme_font_size_override("font_size", 12)
	add_child(title)

	_chord_label          = Label.new()
	_chord_label.text     = "-"
	_chord_label.position = Vector2(44, 54)
	_chord_label.add_theme_color_override("font_color",    Color(1.0, 0.15, 0.04))
	_chord_label.add_theme_font_size_override("font_size", 34)
	add_child(_chord_label)

func show_chord(chord_name: String) -> void:
	_chord_label.text     = chord_name
	_chord_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := _chord_label.create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(_chord_label, "modulate:a", 0.3, 0.5)

func _build_controls_hint() -> void:
	var lines := [
		"  1-6  ->  pluck string",
		"  Q W E R T Y  ->  chord",
		"  HOLD SPACE + mouse up/down  ->  whammy",
	]
	var bg := ColorRect.new()
	bg.color    = Color(0.03, 0.0, 0.0, 0.75)
	bg.position = Vector2(20, 600)
	bg.size     = Vector2(390, 95)
	add_child(bg)

	for i in range(lines.size()):
		var lbl := Label.new()
		lbl.text     = lines[i]
		lbl.position = Vector2(28, 608 + i * 28)
		lbl.add_theme_color_override("font_color",    Color(0.7, 0.55, 0.5))
		lbl.add_theme_font_size_override("font_size", 13)
		add_child(lbl)
