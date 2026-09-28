extends Control
## 未評価の軸は欠測のまま描画する。3軸すべて揃ったときだけ面を塗る。
const Chrome = preload("res://scripts/ui/cyber_theme.gd")
var metrics: Array[Dictionary] = []
var values: Array[float] = []
var captions: Array[Label] = []
const CENTER_Y := 148.0
const RADIUS := 108.0

func setup(items: Array[Dictionary]) -> void:
	metrics = items
	custom_minimum_size = Vector2(400, 260)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	for item in items:
		var value: float = float(item.part) / item.total if item.total > 0 else -1.0
		values.append(value)
		var caption := Label.new()
		caption.text = item.label
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 17)
		caption.add_theme_color_override("font_color", Chrome.TEXT if value >= 0 else Color("8ca3b8"))
		caption.mouse_filter = Control.MOUSE_FILTER_PASS
		caption.tooltip_text = item.hint + ("\n%d / %d%s" % [item.part, item.total, item.unit] if item.total > 0 else "\n対象となる記録がありません。")
		add_child(caption)
		captions.append(caption)
	resized.connect(_arrange)
	_arrange()

func _arrange() -> void:
	if captions.size() != 3: return
	var positions := [Vector2(size.x / 2 - 80, 0), Vector2(size.x / 2 + 28, 222), Vector2(size.x / 2 - 188, 222)]
	for i in 3:
		captions[i].position = positions[i]
		captions[i].size = Vector2(160, 28)
	queue_redraw()

func _draw() -> void:
	if values.size() != 3: return
	var center := Vector2(size.x / 2, CENTER_Y)
	var radius := RADIUS
	var directions: Array[Vector2] = []
	for i in 3: directions.append(Vector2.from_angle(-PI / 2 + TAU * i / 3))
	for level in [0.25, 0.5, 0.75, 1.0]:
		var ring := PackedVector2Array()
		for direction in directions: ring.append(center + direction * radius * level)
		ring.append(ring[0])
		draw_polyline(ring, Color("69869e") if level == 1.0 else Color("34556f"), 1.8 if level == 1.0 else 1.0, true)
	for i in 3:
		draw_line(center, center + directions[i] * radius, Color("34556f"), 1, true)
		if values[i] < 0:
			draw_dashed_line(center, center + directions[i] * radius, Color("8297ac"), 1.5, 4, true)
	var points := PackedVector2Array()
	for i in 3: points.append(center + directions[i] * radius * maxf(values[i], 0.0))
	if values.all(func(value): return value >= 0):
		for i in 3:
			var next := (i + 1) % 3
			if values[i] > 0 and values[next] > 0:
				draw_colored_polygon(PackedVector2Array([center, points[i], points[next]]), Color(0.34, 0.89, 0.95, 0.18))
	for i in 3:
		var next := (i + 1) % 3
		if values[i] >= 0 and values[next] >= 0:
			draw_line(points[i], points[next], Chrome.CYAN, 2.5, true)
		if values[i] >= 0:
			draw_circle(points[i], 4, Chrome.CYAN, true, -1, true)
		else:
			draw_circle(center + directions[i] * radius, 4, Color("8297ac"), false, 1.5, true)
	var font := get_theme_default_font()
	draw_string(font, center + Vector2(5, -4), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8ca3b8"))
	draw_string(font, center + Vector2(5, -radius * 0.5), "50", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8ca3b8"))
	draw_string(font, center + Vector2(5, -radius + 5), "100%", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b0c8da"))
