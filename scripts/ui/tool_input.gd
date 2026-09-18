class_name ToolInput
extends Button
const Chrome = preload("res://scripts/ui/cyber_theme.gd")

signal information_dropped(tool: Dictionary, information: Dictionary)
var tool: Dictionary
var target_environment := ""
var case_id := ""
var heading: Label
var hint: Label
var base_tooltip := ""
var selected: Dictionary = {}
var ready_for_input := false
var drop_ready := false
var hover_drop_ready := false:
	set(value):
		if hover_drop_ready != value:
			hover_drop_ready = value
			queue_redraw()
var reviewed := false
var reference_icon: TextureRect

func setup_presentation() -> void:
	base_tooltip = tooltip_text
	text = ""
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("19394d") if state in ["hover", "pressed"] else _resting_color()
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
		style.set_corner_radius_all(4)
		if state == "focus":
			style.border_color = Color("e4f5ff")
			style.border_width_left = 2
		add_theme_stylebox_override(state, style)
	heading = Label.new()
	var is_reference: bool = tool.get("resource_kind") == "references"
	if is_reference:
		reference_icon = Chrome.icon(self, Rect2(10, 11, 22, 22), "res://assets/icons/document.svg")
	heading.position = Vector2(40, 10) if is_reference else Vector2(12, 6)
	heading.add_theme_font_size_override("font_size", 15 if is_reference else 16)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.max_lines_visible = 2
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.text = tool.label
	add_child(heading)
	hint = Label.new()
	hint.position = Vector2(12, 53)
	hint.add_theme_font_size_override("font_size", 12)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.visible = not is_reference
	add_child(hint)
	resized.connect(_layout_labels)
	heading.minimum_size_changed.connect(_layout_labels)
	_layout_labels()
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	update_input({})

func _layout_labels() -> void:
	heading.size = Vector2(size.x - heading.position.x - 22, 0)
	hint.size = Vector2(size.x - 24, 20)
	hint.position.y = heading.get_rect().end.y + 4.0
	custom_minimum_size.y = maxf(44.0, heading.get_rect().end.y + 10.0) if not hint.visible else maxf(64.0, hint.get_rect().end.y + 8.0)

func _resting_color() -> Color:
	return Color("19394d", 0.55) if tool.get("resource_kind") == "tools" else Color.TRANSPARENT

func update_input(input: Dictionary) -> void:
	selected = input.duplicate(true)
	if not is_instance_valid(hint):
		return
	var compatible: bool = not input.is_empty() and input.get("case_id") == case_id and Information.accepts(tool, input)
	ready_for_input = compatible
	var color := Color("e4f5ff")
	if tool.get("resource_kind", "") == "references":
		hint.text = "確認済み · クリックで再表示" if reviewed else "未読 · クリックで読む"
	elif tool.get("resource_kind", "") == "external_references":
		hint.text = "送信：" + Information.input_hint(tool) + (" →" if compatible else "")
		color = Color("57edc2") if compatible else color
	elif compatible:
		hint.text = "この情報を調べる →"
		color = Color("57edc2")
	elif tool.accepted_information_types.is_empty():
		hint.text = "対象全体を調べる"
	else:
		hint.text = "入力：" + Information.input_hint(tool)
	tooltip_text = tool.label + "\n" + base_tooltip + "\n" + hint.text + ("\n選択中: " + input.get("label", "") if compatible else "")
	if not input.is_empty() and not compatible and not tool.accepted_information_types.is_empty():
		tooltip_text += "\n選択した情報は、このToolの調査対象に対応していません。"
	heading.add_theme_color_override("font_color", color)
	hint.add_theme_color_override("font_color", color if compatible else Color("b0c8da"))
	var style := get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	style.bg_color = Color("164255") if compatible else _resting_color()
	add_theme_stylebox_override("normal", style)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(heading):
		return
	if drop_ready or hover_drop_ready:
		draw_style_box(_drop_style(), Rect2(Vector2.ZERO, size))
	if ready_for_input or drop_ready or hover_drop_ready:
		draw_line(Vector2(1, 10), Vector2(1, size.y - 10), Color("57edc2"), 2)
	elif reviewed:
		var point := Vector2(size.x - 12, 22)
		draw_polyline(PackedVector2Array([point + Vector2(-4, 0), point + Vector2(-1, 3), point + Vector2(5, -4)]), Color("57edc2"), 1.5, true)
	elif tool.get("resource_kind") == "external_references":
		var point := Vector2(size.x - 12, 18)
		draw_line(point + Vector2(-4, 4), point + Vector2(4, -4), Color("b0c8da"), 1.5, true)
		draw_polyline(PackedVector2Array([point + Vector2(-3, -4), point + Vector2(4, -4), point + Vector2(4, 3)]), Color("b0c8da"), 1.5, true)

func _drop_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("164255")
	style.set_corner_radius_all(4)
	return style

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and is_instance_valid(hint):
		var data = get_viewport().gui_get_drag_data()
		if _can_drop_data(Vector2.ZERO, data):
			hint.text = "ここにドロップして解析"
			drop_ready = true
			queue_redraw()
	if what == NOTIFICATION_DRAG_END:
		drop_ready = false
		update_input(selected)

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if disabled or not data is Dictionary or data.get("kind") != "information" or not data.get("information") is Dictionary:
		return false
	return data.information.get("case_id") == case_id and Information.accepts(tool, data.information) and ToolRunner.supports_target(tool, {"investigation_environment": target_environment})

func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		information_dropped.emit(tool, data.information)
