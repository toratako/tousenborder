class_name InformationToken
extends PanelContainer
## 選択・比較・ツール入力に使う共通の情報トークン。
signal selected(token: Dictionary)
signal touched

var information: Dictionary
var context: Dictionary
var highlighted := false
var hovered := false
var show_drag_grip := false

func setup(item: Dictionary, card_context: Dictionary, show_label: bool = true) -> void:
	information = item.duplicate(true)
	context = card_context.duplicate(true)
	show_drag_grip = context.get("card_category") == "target" and item.get("category") != "request" and item.draggable and item.tool_input
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_DRAG if show_drag_grip else Control.CURSOR_POINTING_HAND
	tooltip_text = "クリックで選択" + (" / 値をツールへドラッグ" if item.draggable and item.tool_input else "")
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var caption := Label.new()
	caption.text = item.label
	caption.visible = show_label
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color("b0c8da"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)
	var value := Label.new()
	value.text = Information.display(item.value)
	if item.get("data_type") == "console":
		var monospace := SystemFont.new()
		monospace.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
		monospace.fallbacks = [get_theme_font("font")]
		value.add_theme_font_override("font", monospace)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color("e4f5ff"))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(value)
	mouse_entered.connect(func():
		hovered = true
		_style(true))
	mouse_exited.connect(func():
		hovered = false
		_style(false))
	_style(hovered)

func payload() -> Dictionary:
	var token := information.duplicate(true)
	token.merge(context, true)
	return token

func set_selected(value: bool) -> void:
	highlighted = value
	_style(hovered)

func _style(hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	var target: bool = context.get("card_category") == "target"
	style.bg_color = (Color("1a3b50") if target else Color("1b3450")) if hovered or highlighted else Color.TRANSPARENT
	style.border_color = Color("57e4f2")
	style.border_width_left = 3 if highlighted else 0
	style.content_margin_left = 28 if show_drag_grip else 10
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 9
	add_theme_stylebox_override("panel", style)
	queue_redraw()

func _draw() -> void:
	if show_drag_grip:
		var color := Color("e4f5ff") if hovered or highlighted else Color("8297ac")
		for x in [12, 18]:
			for offset in [-6, 0, 6]:
				draw_circle(Vector2(x, size.y / 2 + offset), 1.5, color, true, -1, true)
	if context.get("card_category") == "rule":
		draw_line(Vector2(10, size.y - 1), Vector2(size.x - 8, size.y - 1), Color(0.69, 0.78, 0.85, 0.18), 1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		touched.emit()
		selected.emit(payload())

func _get_drag_data(_position: Vector2) -> Variant:
	if not information.draggable or not information.tool_input:
		return null
	touched.emit()
	var preview := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e32")
	style.border_color = Color("57e4f2")
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	preview.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = information.label + "\n" + Information.display(information.value).left(50)
	label.add_theme_font_override("font", get_theme_font("font"))
	label.add_theme_color_override("font_color", Color("e4f5ff"))
	preview.add_child(label)
	set_drag_preview(preview)
	return {"kind": "information", "information": payload()}
