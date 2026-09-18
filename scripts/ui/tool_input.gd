class_name ToolInput
extends Button

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

func setup_presentation() -> void:
	base_tooltip = tooltip_text
	text = ""
	heading = Label.new()
	heading.position = Vector2(12, 6)
	heading.add_theme_font_size_override("font_size", 15)
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
	add_child(hint)
	resized.connect(_layout_labels)
	heading.minimum_size_changed.connect(_layout_labels)
	_layout_labels()
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	update_input({})

func _layout_labels() -> void:
	heading.size = Vector2(size.x - 30, 44)
	hint.size = Vector2(size.x - 24, 20)
	hint.position.y = maxf(53.0, heading.get_rect().end.y + 4.0)
	custom_minimum_size.y = maxf(78.0, hint.get_rect().end.y + 6.0)

func update_input(input: Dictionary) -> void:
	selected = input.duplicate(true)
	if not is_instance_valid(hint):
		return
	var compatible: bool = not input.is_empty() and input.get("case_id") == case_id and Information.accepts(tool, input)
	ready_for_input = compatible
	var color := Color("e4f5ff")
	if tool.get("resource_kind", "") == "references":
		hint.text = "確認済み · クリックで再表示" if reviewed else "未読 · クリックで読む"
		color = Color("57edc2") if reviewed else color
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
	hint.add_theme_color_override("font_color", color)
	var style := get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	style.bg_color = Color("164255") if compatible else Color("101e32")
	style.border_color = Color("57e4f2") if compatible else Color("34556f")
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("normal", style)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(heading):
		return
	draw_circle(Vector2(size.x - 12, 12), 4, Color("57edc2") if ready_for_input or drop_ready or hover_drop_ready else Color("29495f"))
	if drop_ready or hover_drop_ready:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("57edc2"), false, 3)

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
