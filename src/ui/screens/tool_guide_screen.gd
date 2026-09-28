extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT

signal closed
var categories: Array[Dictionary] = []
var body: RichTextLabel
var close_button: Button
var tabs: Array[Button] = []
var tools: Array[Dictionary] = []


func setup(items: Array[Dictionary], labels: Array[Dictionary]) -> void:
	tools = items
	categories = labels
	_build()
	if not tools.is_empty():
		select_tool(0)
	else:
		body.text = "登録されているツールはありません。"


func _build() -> void:
	ScreenLayout.prepare(self, Color("070e1b"))
	var sheet := Chrome.panel(self, Rect2(80, 55, 1120, 690), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(30, 22, 1060, 45), "調査ツール詳細", INK, 30)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 125)
	scroll.size = Vector2(310, 465)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 9)
	scroll.add_child(list)
	var group := ButtonGroup.new()
	for i in range(tools.size()):
		var tab := Chrome.button(list, Rect2(0, 0, 310, 48), tools[i].label, PAPER)
		tab.custom_minimum_size.y = 48
		tab.clip_text = true
		tab.tooltip_text = tools[i].label
		tab.toggle_mode = true
		tab.button_group = group
		var selected := tab.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
		selected.bg_color = Color("164255")
		selected.border_color = INK
		tab.add_theme_stylebox_override("pressed", selected)
		tab.pressed.connect(select_tool.bind(i))
		tabs.append(tab)
	Chrome.panel(sheet, Rect2(358, 125, 2, 465), Color("34556f"))
	body = Chrome.rich(sheet, Rect2(382, 125, 708, 465), INK, 21)
	close_button = Chrome.button(sheet, Rect2(30, 620, 1060, 42), "タイトル画面に戻る", PAPER)
	close_button.pressed.connect(closed.emit)


func _tool_description(tool: Dictionary) -> String:
	var input_text := (
		"\n必要な入力: " + Information.input_hint(tool)
		if not tool \
				.get("accepted_information_types", []) \
				.is_empty()
		else ""
	)
	var platform_text: String = "\nToolの主な利用環境: " + tool.platform_note if tool.has("platform_note") else ""
	return "対応対象: " + "、".join(tool.categories.map(_category_label)) + platform_text + input_text + "\n\n" + tool.description


func select_tool(index: int) -> void:
	var tool := tools[index]
	body.clear()
	body.push_font_size(30)
	body.add_text(tool.label + "\n\n")
	body.pop()
	body.add_text(_tool_description(tool))
	body.scroll_to_line(0)
	for i in range(tabs.size()):
		tabs[i].set_pressed_no_signal(i == index)


func _category_label(id: String) -> String:
	for category in categories:
		if category.id == id:
			return category.label
	return id
