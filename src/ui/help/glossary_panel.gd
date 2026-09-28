extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT
const MUTED = Chrome.MUTED

signal closed
var scroll: ScrollContainer
var entries_list: VBoxContainer
var close_button: Button
var search: LineEdit
var count: Label
var empty: Label
var viewed: Dictionary = { }
var expanded: Dictionary = { }
var scroll_position := 0
var terms := LearningGlossary.common_terms()


func setup() -> void:
	var parts := ScreenLayout.list_content(self, "用語集")
	scroll = parts.scroll
	entries_list = parts.list
	close_button = parts.close
	close_button.pressed.connect(closed.emit)
	var sheet: Control = parts.scroll.get_parent()
	parts.notice.hide()
	search = LineEdit.new()
	search.position = Vector2(30, 80)
	search.size = Vector2(680, 44)
	search.placeholder_text = "用語を検索"
	search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size", 18)
	search.add_theme_color_override("font_color", INK)
	search.add_theme_color_override("font_placeholder_color", MUTED)
	search.add_theme_color_override("caret_color", Chrome.CYAN)
	search.add_theme_stylebox_override("normal", Chrome.box(Chrome.BACKGROUND, Chrome.BORDER, 16))
	search.add_theme_stylebox_override("focus", Chrome.box(Color.TRANSPARENT, Chrome.CYAN, 16))
	sheet.add_child(search)
	search.text_changed.connect(filter_terms)
	count = Chrome.label(sheet, Rect2(730, 90, 160, 30), "", MUTED, 16)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scroll.position.y = 142
	scroll.size.y = 458
	entries_list.add_theme_constant_override("separation", 12)
	empty = Chrome.label(sheet, Rect2(30, 175, 840, 45), "該当する用語はありません。", MUTED, 18)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.hide()


func show_terms(item: Dictionary, resources: Array[Dictionary]) -> void:
	for child in entries_list.get_children():
		entries_list.remove_child(child)
		child.queue_free()
	var visible_terms := LearningGlossary.visible_terms(item, terms, resources, viewed)
	for term in visible_terms:
		var entry := glossary_entry(entries_list, term, expanded.has(term.id))
		var button: Button = entry.button
		button.toggled.connect(
			func(open: bool):
				entry.body.visible = open
				if open:
					expanded[term.id] = true
				else:
					expanded.erase(term.id),
		)
	filter_terms(search.text)

	show()
	scroll.set_deferred("scroll_vertical", scroll_position)
	search.grab_focus()


func reset() -> void:
	viewed.clear()
	expanded.clear()
	search.set_text("")
	scroll_position = 0


func filter_terms(query: String) -> void:
	var needle := query.strip_edges().to_lower()
	var controls: Array[Control] = [close_button, search]
	var visible_count := 0
	for entry in entries_list.get_children():
		entry.visible = needle.is_empty() or str(entry.get_meta("search_text", "")).contains(needle)
		if entry.visible:
			visible_count += 1
			controls.append(entry.get_child(0))
	count.text = "%d / %d 語" % [visible_count, entries_list.get_child_count()] if not needle.is_empty() else "%d 語" % visible_count
	empty.text = "表示できる用語はありません。" if entries_list.get_child_count() == 0 else "該当する用語はありません。"
	empty.visible = visible_count == 0
	scroll.scroll_vertical = 0
	ScreenLayout.focus_cycle(controls)


static func glossary_entry(parent: Control, term: Dictionary, expanded: bool) -> Dictionary:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	column.set_meta("search_text", (str(term.label) + " " + str(term.description)).to_lower())
	parent.add_child(column)
	var button := Chrome.button(column, Rect2(0, 0, 820, 52), "", PAPER)
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "hover", "pressed", "focus"]:
		var fill := Color("19394d") if state in ["hover", "pressed"] else Color("14263b")
		var style := Chrome.box(
			Color.TRANSPARENT if state == "focus" else fill,
			Chrome.CYAN if state == "focus" else Chrome.BORDER,
			18,
		)
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		button.add_theme_stylebox_override(state, style)
	button.toggle_mode = true
	button.set_pressed_no_signal(expanded)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var body := ScreenLayout.list_label(column, term.description)
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_constant_override("line_spacing", 7)
	var body_style := Chrome.box(Color("0c192b"), Chrome.BORDER, 24)
	body_style.content_margin_top = 16
	body_style.content_margin_bottom = 20
	body.add_theme_stylebox_override("normal", body_style)
	body.visible = expanded
	button.text = ("▾   " if expanded else "▸   ") + str(term.label)
	button.toggled.connect(
		func(open: bool):
			button.text = ("▾   " if open else "▸   ") + str(term.label),
	)
	return { "button": button, "body": body }
