extends RefCounted
## Shared presentation primitives. Screens own their controls, signals and state.
const Chrome = preload("res://src/ui/shared/game_theme.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT
const RED = Chrome.RED


static func prepare(panel: Panel, color: Color) -> void:
	panel.position = Vector2.ZERO
	panel.size = Vector2(1280, 800)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = color
	panel.add_theme_stylebox_override("panel", style)


static func list_content(parent: Panel, title: String) -> Dictionary:
	var overlay := parent
	prepare(overlay, Color(0.02, 0.04, 0.09, 0.85))
	var sheet := Chrome.panel(overlay, Rect2(180, 55, 920, 690), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(30, 22, 860, 45), title, INK, 30)
	var notice := Chrome.label(sheet, Rect2(30, 78, 860, 30), "", RED, 15)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 115)
	scroll.size = Vector2(860, 485)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	sheet.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var close := Chrome.button(sheet, Rect2(30, 620, 860, 42), "閉じる", PAPER)
	overlay.hide()
	return { "scroll": scroll, "list": list, "close": close, "notice": notice }


static func list_label(parent: Control, text: String) -> Label:
	var label := Chrome.label(parent, Rect2(0, 0, 820, 30), text, INK, 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func focus_cycle(buttons: Array) -> void:
	for i in buttons.size():
		var button: Control = buttons[i]
		button.focus_previous = button.get_path_to(
			buttons[(i - 1 + buttons.size()) % buttons.size()]
		)
		button.focus_next = button.get_path_to(buttons[(i + 1) % buttons.size()])
		button.focus_neighbor_top = button.focus_previous
		button.focus_neighbor_bottom = button.focus_next
