class_name DraggableCard
extends Panel
## すべての机上資料で共有。情報の意味や採点には依存しない。
const Chrome = preload("res://scripts/ui/cyber_theme.gd")

signal information_selected(token: Dictionary)
signal stamp_dropped(card: DraggableCard, data: Dictionary)
signal activated(card: DraggableCard)

var card_data: Dictionary
var home_position := Vector2.ZERO
var home_size := Vector2.ZERO
var minimum_position := Vector2.ZERO
var scroll: ScrollContainer
var source_label: Label
var scroll_hint: Label
var accent := Color("57e4f2")
var active := false
var dragging := false:
	set(value):
		dragging = value
		if is_instance_valid(header):
			var paper := get_theme_stylebox("panel") as StyleBoxFlat
			paper.shadow_size = 14 if dragging else 8
			paper.shadow_offset = Vector2(6, 10) if dragging else Vector2(4, 6)
			_header_style(header_hovered)
var movable := true
var drag_offset := Vector2.ZERO
var header: Panel
var header_hovered := false
var title_label: Label
var title_icon: TextureRect
var rows: VBoxContainer
var request_section: VBoxContainer
var basic_section: VBoxContainer
var tokens: Array[InformationToken] = []
var stamp_validator: Callable
var stamp_mark: Label
var stamp_plate: Panel
var imprint := false
var drop_available := false
var hover_drop_available := false:
	set(value):
		if hover_drop_available != value:
			hover_drop_available = value
			queue_redraw()
var close_button: Button
var fit_pending := false
var analysis_overflow := false

func setup(data: Dictionary, origin: Vector2, dimensions := Vector2(380, 450)) -> void:
	card_data = data.duplicate(true)
	movable = data.get("category") != "target"
	home_position = origin
	position = origin
	size = dimensions
	home_size = dimensions
	accent = {"target": Color("57e4f2"), "analysis": Color("85b5ff"), "rule": Color("c5a1ff"), "log": Color("c5a1ff")}.get(data.get("category", ""), Color("57e4f2"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("0d2332") if data.get("category") == "target" else Color("101e32")
	paper.border_color = Color("34556f")
	paper.set_border_width_all(1)
	paper.shadow_color = Color(0, 0, 0, 0.3)
	paper.shadow_size = 8
	paper.shadow_offset = Vector2(4, 6)
	add_theme_stylebox_override("panel", paper)
	_build_header(data)
	_build_scroll(data)
	_build_information(data)
	if data.get("category") == "target":
		_build_stamp_plate()
	for surface in [header, scroll, scroll.get_v_scroll_bar(), rows]:
		surface.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
	scroll_hint = Label.new()
	scroll_hint.add_theme_font_size_override("font_size", 12)
	scroll_hint.add_theme_color_override("font_color", Color("b0c8da"))
	scroll_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scroll_hint)
	_layout()
	if data.get("category") == "analysis":
		rows.minimum_size_changed.connect(_queue_content_fit)
		get_parent_control().resized.connect(_queue_content_fit)
		_queue_content_fit()

func _build_header(data: Dictionary) -> void:
	header = Panel.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(size.x, 46)
	header.mouse_default_cursor_shape = Control.CURSOR_DRAG if movable else Control.CURSOR_ARROW
	header.tooltip_text = data.get("title", "資料") + ("\nドラッグして移動" if movable else "")
	header.draw.connect(_draw_grip)
	header.gui_input.connect(_header_input)
	header.mouse_entered.connect(func(): _header_style(true))
	header.mouse_exited.connect(func(): _header_style(false))
	add_child(header)
	_header_style(false)
	title_icon = Chrome.icon(header, Rect2(28 if movable else 10, 10, 26, 26), data.get("icon", "res://assets/icons/document.svg"))
	title_label = Label.new()
	title_label.position = Vector2(62 if movable else 44, 10)
	title_label.size = Vector2(size.x - 134, 28)
	title_label.text = data.get("title", "資料")
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 20 if data.get("category") == "target" else 18)
	title_label.tooltip_text = title_label.text
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_label)
	close_button = _small_button("×", Vector2(size.x - 40, 7))
	close_button.tooltip_text = "規則集を閉じる" if data.get("category") == "rule" else "解析結果を閉じる"
	close_button.visible = data.get("category", "") != "target"
	close_button.pressed.connect(hide)

func _build_scroll(data: Dictionary) -> void:
	source_label = Label.new()
	source_label.position = Vector2(14, 52)
	source_label.size = Vector2(size.x - 28, 24)
	var kind: String = {"target": "審査対象", "analysis": "解析結果", "rule": "運用規則", "log": "調査記録"}.get(data.get("category", ""), "参考資料")
	source_label.text = kind + "  /  " + data.get("source", "")
	source_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	source_label.add_theme_color_override("font_color", Color("b0c8da"))
	source_label.add_theme_font_size_override("font_size", 13)
	source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(source_label)
	source_label.visible = data.get("category") not in ["target", "rule"]
	scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 82)
	scroll.size = Vector2(size.x - 20, size.y - 146 if data.get("category") == "target" else size.y - 94)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.gui_input.connect(_gui_input)
	scroll.get_v_scroll_bar().gui_input.connect(_gui_input)
	scroll.get_v_scroll_bar().changed.connect(_update_scroll_hint)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value): _update_scroll_hint())
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.mouse_filter = Control.MOUSE_FILTER_PASS
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)

func _build_information(data: Dictionary) -> void:
	if data.get("category") == "target":
		rows.add_theme_constant_override("separation", 16)
		request_section = _section("申請内容")
		basic_section = _section("基本情報", "項目をツールへドラッグ")
	for item in Information.normalize(data.get("information", []), data.get("source", "")):
		var token := InformationToken.new()
		var is_request: bool = data.get("category") == "target" and item.category == "request"
		var destination := rows
		if data.get("category") == "target":
			destination = request_section if is_request else basic_section
		destination.add_child(token)
		token.setup(item, {"case_id": data.get("case_id", ""), "card_id": data.get("id", ""), "card_category": data.get("category", "")}, not is_request)
		token.touched.connect(bring_to_front)
		token.selected.connect(func(value): information_selected.emit(value))
		token.set_drag_forwarding(token._get_drag_data, _can_drop_data, _drop_data)
		tokens.append(token)

func _build_stamp_plate() -> void:
	stamp_plate = Panel.new()
	stamp_plate.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	stamp_plate.add_theme_stylebox_override("panel", style)
	add_child(stamp_plate)
	stamp_plate.hide()
	stamp_mark = Label.new()
	stamp_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp_mark.add_theme_font_size_override("font_size", 16)
	stamp_mark.add_theme_color_override("font_color", Color("b0c8da"))
	stamp_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_plate.add_child(stamp_mark)
	stamp_plate.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)

func _queue_content_fit() -> void:
	if fit_pending:
		return
	fit_pending = true
	_fit_content.call_deferred()

func _fit_content() -> void:
	fit_pending = false
	if not is_inside_tree():
		return
	var content_height := rows.get_combined_minimum_size().y
	var maximum := get_parent_control().size.y - 24.0
	analysis_overflow = content_height + 94.0 > maximum
	size.y = minf(maxf(140.0, content_height + (116.0 if analysis_overflow else 94.0)), maximum)
	_layout()
	clamp_to_desk()

func _section(caption: String, hint: String = "") -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 5)
	rows.add_child(column)
	var heading_row := HBoxContainer.new()
	heading_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_row.add_theme_constant_override("separation", 12)
	column.add_child(heading_row)
	var heading := Label.new()
	heading.text = caption
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", Color("57e4f2"))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_row.add_child(heading)
	if not hint.is_empty():
		var instruction := Label.new()
		instruction.text = hint
		instruction.add_theme_font_size_override("font_size", 12)
		instruction.add_theme_color_override("font_color", Color("8297ac"))
		instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading_row.add_child(instruction)
	column.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
	return column

func set_geometry(origin: Vector2, dimensions: Vector2) -> void:
	dragging = false
	position = origin
	size = dimensions
	_layout()
	clamp_to_desk()

func _layout() -> void:
	header.size.x = size.x
	title_label.size.x = size.x - title_label.position.x - (48 if close_button.visible else 14)
	close_button.position.x = size.x - 40
	source_label.size.x = size.x - 28
	var target: bool = card_data.get("category") == "target"
	if target:
		var text_width := title_label.get_theme_font("font").get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var title_width := minf(ceilf(text_width), size.x - 84)
		var left := (size.x - title_width - 36) / 2
		title_icon.position = Vector2(left, 9)
		title_icon.size = Vector2(28, 28)
		title_label.position = Vector2(left + 36, 7)
		title_label.size = Vector2(title_width, 32)
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scroll.position = Vector2(12, 58 if target else 82)
	scroll.size = Vector2(size.x - 24, size.y - 116)
	if target:
		scroll.size.y = size.y - (138 if imprint else 70)
	if card_data.get("category") == "rule":
		scroll.position.y = 58
		scroll.size.y = size.y - 70
	if card_data.get("category") == "analysis" and not analysis_overflow:
		scroll.size.y = size.y - 94
	if is_instance_valid(stamp_plate):
		stamp_plate.position = Vector2(24, size.y - 72)
		stamp_plate.size = Vector2(size.x - 48, 55)
		stamp_mark.size = stamp_plate.size
	scroll_hint.position = Vector2(18, size.y - (94 if target else 28))
	scroll_hint.size = Vector2(size.x - 36, 20)
	_update_scroll_hint()

func _update_scroll_hint() -> void:
	if not is_instance_valid(scroll_hint):
		return
	if card_data.get("category") in ["rule", "target"]:
		scroll_hint.hide()
		return
	var bar := scroll.get_v_scroll_bar()
	scroll_hint.text = "↓ 続きがあります · 本文をスクロール" if bar.value + bar.page < bar.max_value - 1 else ""

func set_active(value: bool) -> void:
	active = value
	var paper := get_theme_stylebox("panel") as StyleBoxFlat
	paper.border_color = accent.darkened(0.45) if active else Color("34556f")
	_header_style(header_hovered)

func _small_button(text: String, origin: Vector2) -> Button:
	var button := Button.new()
	button.position = origin
	button.size = Vector2(32, 32)
	button.text = text
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header.add_child(button)
	return button

func _header_style(hovered: bool) -> void:
	header_hovered = hovered
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.08 if hovered or dragging else 0.035) if movable else Color.TRANSPARENT
	header.add_theme_stylebox_override("panel", style)
	if is_instance_valid(title_label):
		title_label.add_theme_color_override("font_color", accent if active else Chrome.TEXT)
	header.queue_redraw()

func _draw_grip() -> void:
	if not movable:
		return
	var color := Chrome.TEXT if header_hovered or dragging else Color("8297ac")
	for x in [12, 18]:
		for y in [17, 23, 29]:
			header.draw_circle(Vector2(x, y), 1.5, color, true, -1, true)

func bring_to_front() -> void:
	get_parent().move_child(self, -1)
	activated.emit(self)

func clamp_to_desk() -> void:
	var maximum := (get_parent_control().size - size).max(Vector2.ZERO)
	position = position.clamp(minimum_position.min(maximum), maximum)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		bring_to_front()

func _header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			bring_to_front()
			if movable:
				dragging = true
				drag_offset = get_parent_control().get_local_mouse_position() - position
		else:
			dragging = false
		header.accept_event()

func _process(_delta: float) -> void:
	if dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not is_visible_in_tree():
			dragging = false
			return
		position = get_parent_control().get_local_mouse_position() - drag_offset
		clamp_to_desk()

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return card_data.get("category") == "target" and data is Dictionary and data.get("kind") == "stamp" and stamp_validator.is_valid() and stamp_validator.call(data)

func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		bring_to_front()
		stamp_dropped.emit(self, data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and is_instance_valid(header):
		drop_available = _can_drop_data(Vector2.ZERO, get_viewport().gui_get_drag_data())
		queue_redraw()
	if what == NOTIFICATION_DRAG_END:
		drop_available = false
		queue_redraw()

func _draw() -> void:
	if drop_available or hover_drop_available:
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color("57edc2"), false, 4)

func show_imprint(caption: String, color: Color) -> void:
	imprint = true
	stamp_plate.show()
	_layout()
	stamp_mark.text = caption
	stamp_mark.add_theme_font_size_override("font_size", 30)
	stamp_mark.add_theme_color_override("font_color", color)
	var style := stamp_plate.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.set_border_width_all(3)
	stamp_plate.add_theme_stylebox_override("panel", style)
	stamp_plate.pivot_offset = stamp_plate.size / 2
	stamp_plate.rotation = -0.04
	stamp_plate.scale = Vector2(1.14, 1.14)
	var tween := create_tween()
	tween.tween_property(stamp_plate, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
