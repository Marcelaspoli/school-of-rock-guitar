extends Node2D
class_name Guitar

signal strummed(string_idx: int, frequency: float, velocity: float)
signal chord_strummed(chord_name: String, frequencies: Array)
signal whammy_changed(bend: float)

const STRING_FREQ: Array[float] = [82.41, 110.00, 146.83, 196.00, 246.94, 329.63]

const KEY_MAP: Dictionary = {
	KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5
}

const CHORD_DEFS: Dictionary = {
	"Em": [82.41,  123.47, 164.81, 196.00, 246.94, 329.63],
	"Am": [110.00, 146.83, 164.81, 220.00, 261.63, 329.63],
	"G":  [98.00,  123.47, 146.83, 196.00, 246.94, 392.00],
	"D":  [0.0,    0.0,   146.83,  220.00, 293.66, 369.99],
	"A":  [0.0,   110.00, 164.81,  220.00, 277.18, 329.63],
	"E":  [82.41,  123.47, 164.81, 207.65, 246.94, 329.63],
}
const CHORD_KEYS: Dictionary = {
	KEY_Q: "Em", KEY_W: "Am", KEY_E: "G",
	KEY_R: "D",  KEY_T: "A",  KEY_Y: "E",
}

# NECK_NUT  = where strings start (headstock end)
# NECK_BRIDGE = where strings end (bridge end, inside body)
# Moving these two points changes the neck angle for ALL drawing functions at once.
const NECK_NUT    := Vector2(-175, -100)
const NECK_BRIDGE := Vector2(  90,   52)
const STRING_SPREAD := 16.0

# Wound strings (E A D G) are bronze; plain strings (B e) are nickel/silver.
# Widths follow real gauge proportions.
const STRING_WIDTHS: Array[float]  = [4.4, 3.6, 2.8, 2.1, 1.5, 1.05]
const STRING_COLORS_NORMAL: Array  = [
	Color(0.68, 0.46, 0.18),   # low E  — wound bronze
	Color(0.66, 0.44, 0.17),   # A      — wound bronze
	Color(0.64, 0.43, 0.16),   # D      — wound bronze
	Color(0.62, 0.42, 0.16),   # G      — wound bronze
	Color(0.84, 0.84, 0.78),   # B      — plain nickel
	Color(0.90, 0.90, 0.85),   # high e — plain nickel
]
const STRING_COLOR_LIT := Color(1.0, 0.86, 0.12)

var _string_lines: Array[Line2D] = []
var _held_keys:    Dictionary    = {}
var _glow:         float         = 0.0

var _whammy_active:   bool  = false
var _whammy_origin_y: float = 0.0

func _ready() -> void:
	_build_string_lines()
	set_process_input(true)

func _build_string_lines() -> void:
	var nd := (NECK_BRIDGE - NECK_NUT).normalized()
	var pp := Vector2(-nd.y, nd.x)
	for i in range(6):
		var off  := (i - 2.5) * STRING_SPREAD
		var line := Line2D.new()
		line.add_point(NECK_NUT    + pp * off)
		line.add_point(NECK_BRIDGE + pp * off)
		line.width         = STRING_WIDTHS[i]
		line.default_color = STRING_COLORS_NORMAL[i]
		line.z_index       = 5
		add_child(line)
		_string_lines.append(line)

func _draw() -> void:
	_draw_body()
	_draw_neck_wood()
	_draw_frets()
	_draw_headstock()
	_draw_hardware()
	# Cream binding sits on top of everything else
	draw_polyline(_body_points(), Color(0.94, 0.91, 0.80), 2.8, true)

# Single-cutaway Les Paul silhouette, built relative to the neck axis
# so body, neck, strings and hardware all stay aligned automatically.
func _body_points() -> PackedVector2Array:
	var nd  := (NECK_BRIDGE - NECK_NUT).normalized()  # along neck toward bridge
	var pp  := Vector2(-nd.y, nd.x)                   # perpendicular (bass side = positive)
	# The body origin sits a little past NECK_BRIDGE, toward the tailpiece.
	var o   := NECK_BRIDGE + nd * 18.0

	# All offsets are (along-neck, across-neck) from o.
	# nd positive  = toward tailpiece
	# pp positive  = toward bass side (left when neck points upper-left)
	return PackedVector2Array([
		# Heel / neck joint — bass side
		o + nd * -18.0 + pp *  52.0,
		# Upper bass bout sweeps out
		o + nd * -50.0 + pp *  78.0,
		o + nd * -80.0 + pp *  82.0,
		o + nd * -95.0 + pp *  62.0,
		# Upper bass shoulder rounds off
		o + nd * -98.0 + pp *  30.0,
		o + nd * -98.0 + pp *   0.0,
		o + nd * -95.0 - pp *  28.0,
		# Cutaway horn begins (treble side, upper bout)
		o + nd * -75.0 - pp *  62.0,
		o + nd * -42.0 - pp *  76.0,   # horn tip
		o + nd * -10.0 - pp *  60.0,   # cutaway bites in toward neck
		# Heel — treble side
		o + nd * -18.0 - pp *  52.0,
		# Waist — treble side pinch
		o + nd *  18.0 - pp *  68.0,
		# Lower treble bout swells out
		o + nd *  58.0 - pp *  98.0,
		o + nd *  98.0 - pp * 110.0,
		o + nd * 138.0 - pp * 108.0,
		# Tailpiece end — rounded bottom
		o + nd * 155.0 - pp *  60.0,
		o + nd * 160.0 + pp *   0.0,
		o + nd * 155.0 + pp *  60.0,
		# Lower bass bout swells out
		o + nd * 138.0 + pp * 108.0,
		o + nd *  98.0 + pp * 110.0,
		o + nd *  58.0 + pp *  98.0,
		# Waist — bass side pinch
		o + nd *  18.0 + pp *  68.0,
		# Close back to heel
		o + nd * -18.0 + pp *  52.0,
	])

# Returns a copy of pts scaled toward their centroid by factor
func _scale_polygon(pts: PackedVector2Array, factor: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p in pts:
		center += p
	center /= pts.size()
	var result := PackedVector2Array()
	for p in pts:
		result.append(center + (p - center) * factor)
	return result

func _draw_body() -> void:
	var g   := _glow
	var pts := _body_points()

	# Cherry sunburst: dark near-black outer edge fading to amber at center.
	# Simulated with three overlapping scaled polygons.
	var outer  := Color(0.10 + g * 0.06, 0.01,           0.005)
	var mid    := Color(0.36 + g * 0.14, 0.04 + g * 0.03, 0.01)
	var inner  := Color(0.52 + g * 0.12, 0.22 + g * 0.04, 0.05)
	var centre := Color(0.62 + g * 0.10, 0.32 + g * 0.03, 0.07)

	draw_polygon(pts,                          PackedColorArray([outer]))
	draw_polygon(_scale_polygon(pts, 0.74),    PackedColorArray([mid]))
	draw_polygon(_scale_polygon(pts, 0.50),    PackedColorArray([inner]))
	draw_polygon(_scale_polygon(pts, 0.26),    PackedColorArray([centre]))

	# Warm amber bloom when a note rings out — centred on body
	if g > 0.06:
		var nd  := (NECK_BRIDGE - NECK_NUT).normalized()
		var pp  := Vector2(-nd.y, nd.x)
		var o   := NECK_BRIDGE + nd * 18.0
		var bc  := o + nd * 60.0   # bloom centre, middle of lower bout
		var bloom_pts := PackedVector2Array([
			bc + nd * -50.0 + pp *  40.0,
			bc + nd * -70.0 + pp *   0.0,
			bc + nd * -50.0 - pp *  40.0,
			bc + nd *   0.0 - pp *  70.0,
			bc + nd *  60.0 - pp *  65.0,
			bc + nd *  90.0 + pp *   0.0,
			bc + nd *  60.0 + pp *  65.0,
			bc + nd *   0.0 + pp *  70.0,
			bc + nd * -50.0 + pp *  40.0,
		])
		draw_polygon(bloom_pts, PackedColorArray([Color(0.90, 0.30 * g, 0.04 * g, g * 0.28)]))

func _draw_neck_wood() -> void:
	var nd      := (NECK_BRIDGE - NECK_NUT).normalized()
	var pp      := Vector2(-nd.y, nd.x)
	var mahog   := Color(0.33, 0.18, 0.07)   # maple neck
	var rosewood := Color(0.11, 0.055, 0.022) # dark rosewood fretboard
	var binding := Color(0.94, 0.91, 0.80)    # cream binding

	var body_hw := 29.0
	var nut_hw  := 18.0

	var neck_pts := PackedVector2Array([
		NECK_NUT    + pp *  nut_hw,
		NECK_BRIDGE + pp *  body_hw,
		NECK_BRIDGE - pp *  body_hw,
		NECK_NUT    - pp *  nut_hw,
	])
	draw_polygon(neck_pts, PackedColorArray([mahog]))

	# Subtle grain lines along the neck
	for g_i in range(3):
		var gf: float = 0.2 + float(g_i) * 0.3
		var g_col := Color(0.28, 0.14, 0.055, 0.25)
		draw_line(
			NECK_NUT.lerp(NECK_BRIDGE, gf)    + pp * (-nut_hw * 0.6),
			NECK_NUT.lerp(NECK_BRIDGE, gf + 0.1) + pp * (-body_hw * 0.6),
			g_col, 1.0
		)

	# Fretboard surface
	var fb_hw_nut  := nut_hw  * 0.86
	var fb_hw_body := body_hw * 0.86
	var fb_pts := PackedVector2Array([
		NECK_NUT    + pp *  fb_hw_nut,
		NECK_BRIDGE + pp *  fb_hw_body,
		NECK_BRIDGE - pp *  fb_hw_body,
		NECK_NUT    - pp *  fb_hw_nut,
	])
	draw_polygon(fb_pts, PackedColorArray([rosewood]))

	# Cream binding strips along both fretboard edges
	draw_line(NECK_NUT + pp *  fb_hw_nut,  NECK_BRIDGE + pp *  fb_hw_body, binding, 2.2)
	draw_line(NECK_NUT - pp *  fb_hw_nut,  NECK_BRIDGE - pp *  fb_hw_body, binding, 2.2)

	# Nut — small white block at the headstock end of the fretboard
	var nut_center := NECK_NUT
	draw_line(nut_center + pp * fb_hw_nut, nut_center - pp * fb_hw_nut,
		Color(0.92, 0.88, 0.76), 4.5)

func _draw_frets() -> void:
	var fret_c  := Color(0.72, 0.72, 0.62, 0.95)
	var dot_c   := Color(0.90, 0.88, 0.72)           # mother-of-pearl style
	var dot_rim := Color(0.60, 0.58, 0.44, 0.55)
	var nd      := (NECK_BRIDGE - NECK_NUT).normalized()
	var pp      := Vector2(-nd.y, nd.x)

	# Equal-temperament fret positions: fret n sits at
	# 1 - 2^(-n/12) of the scale length, normalized so fret 12 = 0.90
	for i in range(1, 16):
		var t  := (1.0 - pow(2.0, -float(i) / 12.0)) * 2.0 * 0.90
		if t > 1.0:
			break
		var fp := NECK_NUT.lerp(NECK_BRIDGE, t)
		var hw := lerpf(15.0, 25.0, t)
		draw_line(fp + pp * hw, fp - pp * hw, fret_c, 1.6)

		# Inlay dots at standard positions
		if i in [3, 5, 7, 9]:
			var dot_pos := fp
			draw_circle(dot_pos, 5.2, dot_rim)
			draw_circle(dot_pos, 4.2, dot_c)
		elif i == 12:
			draw_circle(fp + pp * 9, 5.2, dot_rim)
			draw_circle(fp + pp * 9, 4.2, dot_c)
			draw_circle(fp - pp * 9, 5.2, dot_rim)
			draw_circle(fp - pp * 9, 4.2, dot_c)

func _draw_headstock() -> void:
	var wood    := Color(0.22, 0.11, 0.05)
	var peg_hub := Color(0.12, 0.12, 0.12)
	var peg_btn := Color(0.18, 0.18, 0.18)   # dark plastic tuner button
	var chrome  := Color(0.72, 0.72, 0.76)
	var binding := Color(0.94, 0.91, 0.80)
	var nd      := (NECK_BRIDGE - NECK_NUT).normalized()
	var pp      := Vector2(-nd.y, nd.x)
	var tip     := NECK_NUT + nd * -68.0

	# Les Paul-style headstock silhouette — slightly asymmetric flare
	var hs := PackedVector2Array([
		NECK_NUT    + pp *  18,
		tip         + pp *  28,
		tip + nd * -22 + pp * 22,
		tip + nd * -38 + pp *  8,
		tip + nd * -38 - pp *  8,
		tip + nd * -22 - pp * 22,
		tip         - pp *  28,
		NECK_NUT    - pp *  18,
	])
	draw_polygon(hs, PackedColorArray([wood]))
	draw_polyline(hs, binding, 2.0, true)

	# Truss rod cover — small dark teardrop inset below nut
	var trc := NECK_NUT + nd * -12
	draw_rect(Rect2(trc.x - 7, trc.y - 3, 14, 8), Color(0.08, 0.04, 0.02))
	draw_rect(Rect2(trc.x - 7, trc.y - 3, 14, 8), Color(0.30, 0.20, 0.08, 0.6), false, 1.0)

	# Logo inlay plate
	var logo_c := tip + nd * -10
	draw_rect(Rect2(logo_c.x - 15, logo_c.y - 4, 30, 9), Color(0.70, 0.60, 0.20, 0.80))

	# 3+3 tuning machines — hub + button shape
	for i in range(3):
		var along := nd * (-8 - i * 16)
		for side in [-1, 1]:
			var s    := int(side)
			var peg  : Vector2 = tip + along + pp * (24.0 * s)
			# Mounting plate
			draw_rect(Rect2(peg.x - 5, peg.y - 5, 10, 10), peg_hub)
			# Gear hub
			draw_circle(peg, 6.0, peg_hub)
			draw_circle(peg, 4.5, chrome)
			draw_circle(peg, 2.0, Color(0.08, 0.08, 0.10))
			# Tuner button (extends perpendicular to headstock)
			var btn : Vector2 = peg + pp * (8.0 * s)
			draw_circle(btn, 4.5, peg_btn)
			draw_circle(btn, 3.0, Color(0.26, 0.26, 0.28))

func _draw_hardware() -> void:
	var chrome    := Color(0.72, 0.72, 0.78)
	var chrome_hi := Color(0.92, 0.92, 0.96)  # specular highlight
	var gold      := Color(0.78, 0.68, 0.18)
	var cream     := Color(0.92, 0.88, 0.74)   # pickup ring colour
	var g         := _glow
	var pu_glow   := Color(0.10 + g * 0.40, 0.0, 0.0)

	# All hardware is positioned relative to the neck axis so it moves
	# correctly whenever NECK_NUT / NECK_BRIDGE are adjusted.
	var nd  := (NECK_BRIDGE - NECK_NUT).normalized()
	var pp  := Vector2(-nd.y, nd.x)
	var o   := NECK_BRIDGE + nd * 18.0   # body origin (same as _body_points)

	# Neck pickup — sits just inside the body past the heel
	var pu_neck   := o + nd * 28.0
	# Bridge pickup — further toward tailpiece
	var pu_bridge := o + nd * 68.0

	_draw_pickup_ring(pu_neck,   cream)
	_draw_humbucker(pu_neck,     chrome, pu_glow)
	_draw_pickup_ring(pu_bridge, cream)
	_draw_humbucker(pu_bridge,   chrome, pu_glow)

	# Tune-o-matic bridge — sits between bridge pickup and tailpiece
	var br := o + nd * 100.0
	# Draw bridge rect perpendicular to neck axis
	var br_h := pp * 9.0
	var br_w := nd * 22.0
	var br_pts := PackedVector2Array([
		br - br_w + br_h,
		br + br_w + br_h,
		br + br_w - br_h,
		br - br_w - br_h,
	])
	draw_polygon(br_pts, PackedColorArray([chrome]))
	draw_line(br - br_w + br_h, br + br_w + br_h, chrome_hi, 1.2)
	for s in range(6):
		var t   := (float(s) / 5.0 - 0.5) * 2.0
		var sp  := br + nd * (t * 18.0)
		draw_line(sp + pp * 7, sp - pp * 7, Color(0.50, 0.50, 0.55), 4.0)

	# Stop tailpiece — further toward tailpiece end
	var tail := o + nd * 122.0
	var tl_h := pp * 6.0
	var tl_w := nd * 24.0
	var tl_pts := PackedVector2Array([
		tail - tl_w + tl_h,
		tail + tl_w + tl_h,
		tail + tl_w - tl_h,
		tail - tl_w - tl_h,
	])
	draw_polygon(tl_pts, PackedColorArray([chrome]))
	draw_line(tail - tl_w + tl_h, tail + tl_w + tl_h, chrome_hi, 1.2)
	for h in range(6):
		var t   := (float(h) / 5.0 - 0.5) * 2.0
		draw_circle(tail + nd * (t * 19.0), 3.2, Color(0.28, 0.28, 0.34))

	# Four control knobs (2 volume, 2 tone) — gold top-hats
	# Placed in the lower bout, bass side
	var knob_positions := [
		o + nd * 90.0  + pp * 62.0,
		o + nd * 110.0 + pp * 78.0,
		o + nd * 90.0  + pp * 88.0,
		o + nd * 110.0 + pp * 100.0,
	]
	for kp in knob_positions:
		draw_circle(kp, 12, Color(0.12, 0.12, 0.12))
		draw_circle(kp, 10, gold)
		# Knurled edge suggestion
		draw_circle(kp, 10, Color(0.0, 0.0, 0.0, 0.18), false, 1.0)
		# Indicator line
		draw_line(kp, kp - nd * 7, Color(0.06, 0.06, 0.06), 2.0)

	# Toggle switch — upper bass bout
	var sw := o + nd * -40.0 + pp * 65.0
	var sw_perp := pp * 5.0
	var sw_along := nd * 16.0
	draw_polygon(PackedVector2Array([
		sw - sw_along + sw_perp,
		sw + sw_along + sw_perp,
		sw + sw_along - sw_perp,
		sw - sw_along - sw_perp,
	]), PackedColorArray([chrome]))
	draw_circle(sw - nd * 11.0, 5.5, Color(0.90, 0.90, 0.90))
	draw_circle(sw - nd * 11.0, 3.5, Color(0.70, 0.70, 0.74))

	# Output jack — lower treble bout rim
	var jack := o + nd * 100.0 - pp * 95.0
	draw_circle(jack, 7.0, Color(0.14, 0.14, 0.14))
	draw_circle(jack, 5.0, chrome)
	draw_circle(jack, 2.5, Color(0.08, 0.08, 0.10))

	# Strap buttons — upper bass horn and tailpiece end
	var sb_upper := o + nd * -80.0 + pp * 70.0
	var sb_lower := o + nd * 158.0
	draw_circle(sb_upper, 6.5, chrome)
	draw_circle(sb_upper, 4.0, Color(0.54, 0.54, 0.60))
	draw_circle(sb_lower, 6.5, chrome)
	draw_circle(sb_lower, 4.0, Color(0.54, 0.54, 0.60))

func _draw_pickup_ring(center: Vector2, ring_c: Color) -> void:
	var nd := (NECK_BRIDGE - NECK_NUT).normalized()
	var pp := Vector2(-nd.y, nd.x)
	var outer := PackedVector2Array([
		center + nd * 43 + pp * 15,
		center + nd * 43 - pp * 15,
		center - nd * 43 - pp * 15,
		center - nd * 43 + pp * 15,
	])
	draw_polygon(outer, PackedColorArray([ring_c]))
	# Slight bevel shadow
	draw_polyline(outer, Color(0.0, 0.0, 0.0, 0.35), 1.5, true)

func _draw_humbucker(center: Vector2, frame_c: Color, coil_c: Color) -> void:
	var nd := (NECK_BRIDGE - NECK_NUT).normalized()
	var pp := Vector2(-nd.y, nd.x)
	var frame := PackedVector2Array([
		center + nd * 38 + pp * 10,
		center + nd * 38 - pp * 10,
		center - nd * 38 - pp * 10,
		center - nd * 38 + pp * 10,
	])
	draw_polygon(frame, PackedColorArray([frame_c]))

	# Two coil halves
	for side in [-1, 1]:
		var coil_center: Vector2 = center + nd * (int(side) * 18.0)
		var coil := PackedVector2Array([
			coil_center + nd * 16 + pp * 7,
			coil_center + nd * 16 - pp * 7,
			coil_center - nd * 16 - pp * 7,
			coil_center - nd * 16 + pp * 7,
		])
		draw_polygon(coil, PackedColorArray([coil_c]))

	# Six pole screws across the full width
	for p in range(6):
		var t  := (float(p) / 5.0 - 0.5) * 2.0
		var pc := center + nd * (t * 28)
		draw_circle(pc, 3.0, Color(0.38, 0.38, 0.40))
		draw_circle(pc, 1.4, Color(0.22, 0.22, 0.24))

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key(event as InputEventKey)

func _handle_key(ev: InputEventKey) -> void:
	if KEY_MAP.has(ev.keycode):
		var idx: int = KEY_MAP[ev.keycode]
		if ev.pressed and not ev.is_echo():
			_strum(idx, 0.88)
			_held_keys[idx] = true
		elif not ev.pressed:
			_release(idx)
			_held_keys.erase(idx)
			_refresh_string_colors()

	if CHORD_KEYS.has(ev.keycode) and ev.pressed and not ev.is_echo():
		_strum_chord(CHORD_KEYS[ev.keycode])

	if ev.keycode == KEY_SPACE:
		if ev.pressed and not _whammy_active:
			_whammy_active   = true
			_whammy_origin_y = get_viewport().get_mouse_position().y
		elif not ev.pressed:
			_whammy_active         = false
			AudioEngine.pitch_bend = 0.0
			whammy_changed.emit(0.0)

func _process(delta: float) -> void:
	if _whammy_active:
		var dy   := get_viewport().get_mouse_position().y - _whammy_origin_y
		var bend := clampf(dy / 80.0, -2.5, 2.5)
		AudioEngine.pitch_bend = bend
		whammy_changed.emit(bend)

	_glow = move_toward(_glow, 0.0, delta * 2.8)
	queue_redraw()

func _strum(idx: int, velocity: float) -> void:
	if idx < 0 or idx >= 6:
		return
	AudioEngine.note_on(idx, STRING_FREQ[idx])
	strummed.emit(idx, STRING_FREQ[idx], velocity)
	_animate_string(idx)

func _release(idx: int) -> void:
	AudioEngine.note_off(idx)

func _strum_chord(chord_name: String) -> void:
	if not CHORD_DEFS.has(chord_name):
		return
	var freqs: Array = CHORD_DEFS[chord_name]
	var played: Array = []
	var delay := 0.0

	# Stagger strings by 16 ms to simulate a natural strum sweep
	for i in range(6):
		if freqs[i] <= 0.0:
			continue
		played.append(freqs[i])
		var ci := i
		var cf: float = freqs[i]
		if delay < 0.001:
			AudioEngine.note_on(100 + ci, cf)
			_animate_string(ci)
		else:
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_callback(func():
				AudioEngine.note_on(100 + ci, cf)
				_animate_string(ci)
			)
		delay += 0.016

	chord_strummed.emit(chord_name, played)

func strum_string_external(idx: int, velocity: float = 0.75) -> void:
	_strum(idx, velocity)

func _refresh_string_colors() -> void:
	for i in range(_string_lines.size()):
		_string_lines[i].default_color = (
			STRING_COLOR_LIT if _held_keys.has(i) else STRING_COLORS_NORMAL[i]
		)

func _animate_string(idx: int) -> void:
	_glow = 1.0
	_held_keys[idx] = true
	_refresh_string_colors()
	var tween := create_tween()
	tween.tween_method(_vibrate.bind(idx), 0.0, 1.0, 0.20)
	tween.tween_callback(func():
		if not _held_keys.has(idx):
			_refresh_string_colors()
	)

func _vibrate(t: float, idx: int) -> void:
	if idx >= _string_lines.size():
		return
	var line := _string_lines[idx]
	var nd   := (NECK_BRIDGE - NECK_NUT).normalized()
	var pp   := Vector2(-nd.y, nd.x)
	var base := (idx - 2.5) * STRING_SPREAD
	# Amplitude inversely proportional to string gauge (thinner strings vibrate wider)
	var amp  := sin(t * PI) * lerpf(3.5, 7.0, float(5 - idx) / 5.0)
	line.clear_points()
	for s in range(11):
		var seg_t := float(s) / 10.0
		var pos   := NECK_NUT.lerp(NECK_BRIDGE, seg_t)
		pos += pp * (base + sin(seg_t * PI) * amp)
		line.add_point(pos)
