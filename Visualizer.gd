extends Node2D
## Visualizer — attached to a Node2D in the scene tree.
## Owns all stage effects: background, flames, spotlights, crowd,
## flying notes, lightning, sparks, and amplitude pulse.

const SCREEN_W := 1280.0
const SCREEN_H :=  720.0

var guitar_position: Vector2 = Vector2(520, 360)


var _bg_pulse: float = 0.0   # 0-1, decays toward 0 each frame


var _spot_angles: Array[float] = [-0.4, 0.1, 0.55]
var _spot_dirs:   Array[float] = [ 0.6, -0.45, 0.5]
const SPOT_SPEED := 0.55

#
const CROWD_COUNT := 30
var _crowd_phases:  Array[float] = []
var _crowd_speeds:  Array[float] = []
var _crowd_heights: Array[float] = []


var _lightning_points: Array = []   # Array[PackedVector2Array]
var _lightning_alpha: float = 0.0


class FlyNote:
	var pos:      Vector2
	var vel:      Vector2
	var life:     float = 1.0
	var symbol:   String
	var color:    Color
	var spin:     float
	var angle:    float = 0.0

var _fly_notes: Array = []          # Array[FlyNote]
const NOTE_SYMBOLS := ["♩", "♪", "♫", "♬"]


class Spark:
	var pos:   Vector2
	var vel:   Vector2
	var life:  float = 1.0
	var color: Color

var _sparks: Array = []


var _rock_texts: Array = []   # Array[Label]


var _flames: CPUParticles2D

func _ready() -> void:
	_init_crowd()
	_init_flames()

func _init_crowd() -> void:
	for i in range(CROWD_COUNT):
		_crowd_phases.append(randf() * TAU)
		_crowd_speeds.append(randf_range(1.8, 3.5))
		_crowd_heights.append(randf_range(22, 42))

func _init_flames() -> void:
	_flames = CPUParticles2D.new()
	_flames.position             = Vector2(SCREEN_W * 0.5, SCREEN_H)
	_flames.emitting             = true
	_flames.amount               = 180
	_flames.lifetime             = 1.6
	_flames.explosiveness        = 0.0
	_flames.randomness           = 0.8
	_flames.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flames.emission_rect_extents = Vector2(SCREEN_W * 0.55, 6)
	_flames.direction            = Vector2(0, -1)
	_flames.spread               = 28.0
	_flames.gravity              = Vector2(0, 20)
	_flames.initial_velocity_min = 80.0
	_flames.initial_velocity_max = 220.0
	_flames.scale_amount_min     = 4.0
	_flames.scale_amount_max     = 9.0
	_flames.color                = Color(1.0, 0.3, 0.0, 0.9)
	_flames.color_ramp           = _make_flame_gradient()
	add_child(_flames)

func _make_flame_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.1, 1.0))
	g.add_point(0.35, Color(1.0, 0.35, 0.0, 0.85))
	g.add_point(0.70, Color(0.6, 0.08, 0.0, 0.55))
	g.add_point(1.00, Color(0.1, 0.0,  0.0, 0.00))
	return g


func on_string_strummed(string_idx: int, velocity: float) -> void:
	_bg_pulse = min(1.0, _bg_pulse + velocity * 0.7)
	_spawn_fly_notes(string_idx, velocity)
	_spawn_sparks(velocity)

func on_chord_strummed(chord_name: String) -> void:
	_bg_pulse = 1.0
	_spawn_lightning()
	_spawn_rock_text(chord_name)
	_spawn_sparks(1.0)
	_spawn_fly_notes(2, 1.0)
	_spawn_fly_notes(3, 1.0)

func on_whammy(bend: float) -> void:
	if abs(bend) > 0.5:
		_bg_pulse = min(1.0, _bg_pulse + abs(bend) * 0.3)


func _process(delta: float) -> void:
	
	for i in range(_spot_angles.size()):
		_spot_angles[i] += _spot_dirs[i] * SPOT_SPEED * delta
		if abs(_spot_angles[i]) > 0.85:
			_spot_dirs[i] *= -1.0

	
	for i in range(CROWD_COUNT):
		_crowd_phases[i] += _crowd_speeds[i] * delta

	
	var alive_notes := []
	for n in _fly_notes:
		var fn := n as FlyNote
		fn.pos  += fn.vel * delta
		fn.vel.y -= 30.0 * delta  # float upward
		fn.life  -= delta * 0.9
		fn.angle += fn.spin * delta
		if fn.life > 0.0:
			alive_notes.append(fn)
	_fly_notes = alive_notes

	
	var alive_sparks := []
	for s in _sparks:
		var sp := s as Spark
		sp.pos  += sp.vel * delta
		sp.vel.y += 120.0 * delta  # gravity
		sp.life  -= delta * 2.2
		if sp.life > 0.0:
			alive_sparks.append(sp)
	_sparks = alive_sparks

	
	_lightning_alpha = move_toward(_lightning_alpha, 0.0, delta * 4.5)
	_bg_pulse        = move_toward(_bg_pulse,        0.0, delta * 1.8)

	
	if is_instance_valid(AudioEngine):
		_bg_pulse = max(_bg_pulse, AudioEngine.get_amplitude() * 0.55)

	queue_redraw()

func _draw() -> void:
	_draw_background()
	_draw_spotlights()
	_draw_crowd()
	_draw_lightning()
	_draw_sparks()
	_draw_fly_notes()

func _draw_background() -> void:
	var p      := _bg_pulse
	
	var base   := Color(0.08 + p * 0.14, 0.0, 0.0)
	
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), base)

	
	var edge := Color(0.18 + p * 0.2, 0.01, 0.0, 0.6)
	
	for row in range(6):
		var t := float(row) / 5.0
		var c := base.lerp(Color(0.04, 0.0, 0.0, 1.0), t * 0.55)
		draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H * 0.15 * (1.0 - t)), c)

	
	var floor_c := Color(0.12 + p * 0.10, 0.005, 0.005)
	draw_rect(Rect2(0, SCREEN_H * 0.78, SCREEN_W, SCREEN_H * 0.22), floor_c)

	
	draw_line(Vector2(0, SCREEN_H * 0.78), Vector2(SCREEN_W, SCREEN_H * 0.78),
		Color(0.6 + p * 0.3, 0.05, 0.02, 0.35), 2.0)

func _draw_spotlights() -> void:
	var mount_y := SCREEN_H * 0.02
	var spots := [
		Vector2(SCREEN_W * 0.22, mount_y),
		Vector2(SCREEN_W * 0.50, mount_y),
		Vector2(SCREEN_W * 0.78, mount_y),
	]
	for i in range(spots.size()):
		var origin: Vector2 = spots[i]
		var angle: float    = _spot_angles[i]
		var length: float   = SCREEN_H * 1.1
		var tip: Vector2    = origin + Vector2(sin(angle), 1.0).normalized() * length
		var half_w: float   = length * tan(deg_to_rad(8.0))
		var perp: Vector2   = (tip - origin).normalized().rotated(PI * 0.5)

		var cone_pts := PackedVector2Array([
			origin,
			tip + perp * half_w,
			tip - perp * half_w,
		])
		draw_polygon(cone_pts, PackedColorArray([Color(1.0, 0.7, 0.3, 0.07)]))
		draw_circle(tip, 30.0, Color(1.0, 0.8, 0.4, 0.12))

func _draw_crowd() -> void:
	var base_y := SCREEN_H * 0.80
	var crowd_color_dark := Color(0.06, 0.0, 0.0)
	var crowd_color_lit  := Color(0.20, 0.03, 0.01)
	var spacing := SCREEN_W / float(CROWD_COUNT)

	for i in range(CROWD_COUNT):
		var cx   := spacing * (i + 0.5)
		var bob  := sin(_crowd_phases[i]) * _crowd_heights[i] * 0.5
		var h    := _crowd_heights[i] + bob
		var lit  := (sin(_crowd_phases[i] * 0.8 + float(i)) > 0.4)
		var col  := crowd_color_lit if lit else crowd_color_dark

		
		var head_r := spacing * 0.22
		var body_w := spacing * 0.38
		var body_h := h * 1.2

		draw_circle(Vector2(cx, base_y - h - head_r), head_r, col)
		draw_rect(Rect2(cx - body_w * 0.5, base_y - h, body_w, body_h), col)

		
		if i % 3 == 0:
			var arm_end := Vector2(cx + spacing * 0.4, base_y - h - head_r * 2.5 + bob * 0.5)
			draw_line(Vector2(cx, base_y - h), arm_end, col, 3.5)

func _draw_lightning() -> void:
	if _lightning_alpha < 0.02:
		return
	for bolt in _lightning_points:
		var pts: PackedVector2Array = bolt
		var col := Color(0.9, 0.7, 1.0, _lightning_alpha)
		draw_polyline(pts, col, 2.5, true)
		# Soft glow halo
		draw_polyline(pts, Color(0.6, 0.4, 1.0, _lightning_alpha * 0.3), 8.0, true)

func _draw_sparks() -> void:
	for s in _sparks:
		var sp := s as Spark
		var c  := sp.color
		c.a    = sp.life
		draw_circle(sp.pos, 3.0 * sp.life, c)

func _draw_fly_notes() -> void:
	for n in _fly_notes:
		var fn := n as FlyNote
		if fn.life <= 0.0:
			continue
		var c := fn.color
		c.a   = fn.life
		
		draw_set_transform(fn.pos, fn.angle, Vector2.ONE * lerp(0.5, 1.5, fn.life))
		draw_circle(Vector2.ZERO, 14.0, Color(c.r, c.g, c.b, c.a * 0.3))
		draw_set_transform(Vector2.ZERO)

func _spawn_fly_notes(string_idx: int, velocity: float) -> void:
	var count := int(3 + velocity * 5)
	for _i in range(count):
		var fn        := FlyNote.new()
		fn.pos        = guitar_position + Vector2(randf_range(-80, 80), randf_range(-60, 60))
		fn.vel        = Vector2(randf_range(-90, 90), randf_range(-160, -60))
		fn.symbol     = NOTE_SYMBOLS[randi() % NOTE_SYMBOLS.size()]
		fn.color      = _note_color(string_idx)
		fn.life       = randf_range(0.7, 1.3)
		fn.spin       = randf_range(-2.0, 2.0)
		_fly_notes.append(fn)

func _spawn_sparks(velocity: float) -> void:
	var count := int(8 + velocity * 18)
	for _i in range(count):
		var sp     := Spark.new()
		sp.pos     = guitar_position + Vector2(randf_range(-100, 100), randf_range(-80, 80))
		sp.vel     = Vector2(randf_range(-180, 180), randf_range(-250, -80))
		sp.color   = _spark_color()
		sp.life    = randf_range(0.4, 1.0)
		_sparks.append(sp)

func _spawn_lightning() -> void:
	_lightning_points.clear()
	var bolt_count := randi_range(2, 4)
	for _b in range(bolt_count):
		var pts       := PackedVector2Array()
		var start     := Vector2(randf_range(100, SCREEN_W - 100), 0)
		var end_x     := randf_range(200, SCREEN_W - 200)
		var end_y     := randf_range(SCREEN_H * 0.3, SCREEN_H * 0.7)
		var segments  := 14
		pts.append(start)
		for s in range(1, segments):
			var t       := float(s) / segments
			var mid     := Vector2(lerpf(start.x, end_x, t), lerpf(start.y, end_y, t))
			mid         += Vector2(randf_range(-55, 55), randf_range(-20, 20))
			pts.append(mid)
		pts.append(Vector2(end_x, end_y))
		_lightning_points.append(pts)
	_lightning_alpha = 1.0

func _spawn_rock_text(chord_name: String) -> void:
	var chosen: String = "ROLL!" if randi() % 2 == 0 else "ROCK!"

	var lbl := Label.new()
	lbl.text          = chosen
	lbl.add_theme_color_override("font_color", Color(1.0, 0.1, 0.05))
	lbl.add_theme_font_size_override("font_size", randi_range(38, 72))
	lbl.position      = Vector2(randf_range(100, SCREEN_W - 280),
								randf_range(100, SCREEN_H - 200))
	lbl.modulate.a    = 1.0
	add_child(lbl)
	_rock_texts.append(lbl)

	var tween := lbl.create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 90.0, 0.9)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9)
	tween.tween_callback(lbl.queue_free)


func _note_color(idx: int) -> Color:
	var colors := [
		Color(1.0, 0.15, 0.05),
		Color(1.0, 0.45, 0.0),
		Color(1.0, 0.85, 0.0),
		Color(0.1, 0.9,  0.3),
		Color(0.1, 0.5,  1.0),
		Color(0.8, 0.1,  1.0),
	]
	return colors[clamp(idx, 0, colors.size() - 1)]

func _spark_color() -> Color:
	var sparks := [
		Color(1.0, 0.9, 0.1),
		Color(1.0, 0.5, 0.0),
		Color(1.0, 0.15, 0.05),
		Color(1.0, 1.0, 0.8),
	]
	return sparks[randi() % sparks.size()]
