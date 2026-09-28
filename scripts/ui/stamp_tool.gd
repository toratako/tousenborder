class_name StampTool
extends Control
## 実物のスタンプとしてドラッグし、対象にドロップする。
var stamp_color := Color("57edc2")
var symbol := "stamp"
var caption := ""
var action: Dictionary = { }
var case_id := ""
var generation := 0
var disabled := false
var lifted := false
var hovered := false
var preview_only := false


func payload() -> Dictionary:
	return { "kind": "stamp", "action_id": action.id, "case_id": case_id, "generation": generation }


func _get_drag_data(_position: Vector2) -> Variant:
	if disabled or preview_only:
		return null
	lifted = true
	queue_redraw()
	var preview := Control.new()
	var stamp := StampTool.new()
	stamp.preview_only = true
	stamp.size = size
	stamp.position = -size / 2
	preview.add_child(stamp)
	stamp.configure(action)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_theme_font_override("font", get_theme_font("font"))
	set_drag_preview(preview)
	return payload()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		lifted = false
		queue_redraw()


func configure(action: Dictionary) -> void:
	self.action = action.duplicate(true)
	stamp_color = Color(action.get("color", "8ba879"))
	if action.get("color", "8ba879") == "8ba879":
		stamp_color = Color("57edc2")
	elif action.get("color", "") == "bc6452":
		stamp_color = Color("ff718b")
	symbol = action.get("symbol", "stamp")
	caption = action.label
	tooltip_text = caption + " · 審査対象へドラッグして押印"
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(
		func():
			hovered = true
			queue_redraw(),
	)
	mouse_exited.connect(
		func():
			hovered = false
			queue_redraw(),
	)


func _draw() -> void:
	var center := size.x / 2
	var offset := -3.0 if hovered or preview_only else 0.0
	var color := stamp_color.lightened(0.16) if hovered else stamp_color
	if lifted:
		draw_style_box(
			_box(Color(0, 0, 0, 0.12), stamp_color.darkened(0.65), 5),
			Rect2(8, 36, size.x - 16, 35),
		)
		return
	# 持ち手・軸・ゴム印の台座。
	draw_style_box(_box(Color("050a12"), Color("050a12"), 5), Rect2(13, 36, size.x - 20, 42))
	draw_style_box(_box(color.darkened(0.5), color, 9), Rect2(center - 28, 3 + offset, 56, 24))
	draw_rect(Rect2(center - 12, 25 + offset, 24, 15), color.darkened(0.35))
	draw_style_box(_box(color.darkened(0.7), color, 4), Rect2(8, 36 + offset, size.x - 16, 35))
	var font := get_theme_font("font")
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string(
		font,
		Vector2(center - width / 2 + 8, 59 + offset),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		17,
		color.lightened(0.25),
	)
	var point := Vector2(maxf(18, center - width / 2 - 16), 51 + offset)
	match symbol:
		"check":
			draw_polyline(
				PackedVector2Array(
					[point + Vector2(-5, 0), point + Vector2(-1, 5), point + Vector2(7, -6)]
				),
				color,
				3,
				true,
			)
		"block":
			draw_arc(point, 8, 0, TAU, 24, color, 2, true)
			draw_line(point + Vector2(-5, -5), point + Vector2(5, 5), color, 2, true)
		_:
			draw_line(point + Vector2(0, 7), point + Vector2(0, -7), color, 3, true)
			draw_polyline(
				PackedVector2Array(
					[point + Vector2(-5, -1), point + Vector2(0, -7), point + Vector2(5, -1)]
				),
				color,
				3,
				true,
			)
	if hovered or preview_only:
		draw_line(Vector2(14, size.y - 2), Vector2(size.x - 14, size.y - 2), color, 3, true)


func _box(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(mini(radius, 3))
	style.shadow_color = Color(border, 0.15)
	style.shadow_size = 4
	return style
