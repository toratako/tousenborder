extends RefCounted
## 共通部品の生成と装飾。画面固有の配置・状態には依存しない。
const BACKGROUND := Color("070e1b")
const SURFACE := Color("101e32")
const TEXT := Color("e4f5ff")
const CYAN := Color("57e4f2")
const BORDER := Color("34556f")

static func box(fill: Color, border: Color, padding: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func create(font: Font) -> Theme:
	var result := Theme.new()
	result.default_font = font
	result.default_font_size = 16
	for kind in ["Label", "Button", "OptionButton", "PopupMenu", "CheckButton"]:
		result.set_color("font_color", kind, TEXT)
		result.set_color("font_hover_color", kind, Color.WHITE)
		result.set_color("font_pressed_color", kind, CYAN)
		result.set_color("font_disabled_color", kind, Color("8297ac"))
	result.set_color("default_color", "RichTextLabel", TEXT)
	for kind in ["Button", "OptionButton"]:
		result.set_stylebox("normal", kind, box(SURFACE, BORDER))
		result.set_stylebox("hover", kind, box(Color("19394d"), CYAN))
		result.set_stylebox("pressed", kind, box(Color("164255"), CYAN))
		result.set_stylebox("disabled", kind, box(BACKGROUND, BORDER))
		result.set_stylebox("focus", kind, box(Color.TRANSPARENT, CYAN))
	result.set_stylebox("panel", "PopupMenu", box(SURFACE, CYAN))
	result.set_stylebox("hover", "PopupMenu", box(Color("19394d"), CYAN))
	result.set_stylebox("panel", "TooltipPanel", box(SURFACE, CYAN))
	result.set_color("font_color", "TooltipLabel", TEXT)
	for kind in ["VScrollBar", "HScrollBar"]:
		result.set_stylebox("scroll", kind, box(BACKGROUND, BACKGROUND, 4))
		result.set_stylebox("grabber", kind, box(Color("436982"), Color("436982"), 4))
		result.set_stylebox("grabber_highlight", kind, box(CYAN, CYAN, 4))
		result.set_stylebox("grabber_pressed", kind, box(CYAN, CYAN, 4))
	return result

static func panel(parent: Node, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0 else 0)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

static func label(parent: Node, rect: Rect2, value: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	parent.add_child(label)
	return label

static func rich(parent: Node, rect: Rect2, color: Color, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_color_override("default_color", color)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.selection_enabled = true
	parent.add_child(label)
	return label

static func button(parent: Node, rect: Rect2, value: String, color: Color) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("19394d") if state in ["hover", "focus"] else Color("101e32")
		style.border_color = color.darkened(0.65) if state == "disabled" else color
		if state == "normal":
			style.border_color = Color("34556f")
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
		style.set_corner_radius_all(3)
		style.set_border_width_all(2)
		style.content_margin_left = 12
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("8297ac"))
	parent.add_child(button)
	return button

static func icon(parent: Node, rect: Rect2, path: String) -> TextureRect:
	var image := TextureRect.new()
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path):
		var texture = load(path)
		if texture is Texture2D:
			image.texture = texture
	parent.add_child(image)
	return image
