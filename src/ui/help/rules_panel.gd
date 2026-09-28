extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT
const GREEN = Chrome.GREEN

signal closed
var body: RichTextLabel
var close_button: Button


func setup(rules: Array[Dictionary]) -> void:
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.78))
	var book := Chrome.panel(self, Rect2(200, 55, 880, 690), Color("101e32"), Color("34556f"))
	Chrome.icon(book, Rect2(30, 24, 40, 40), "res://assets/icons/ui/book.svg")
	Chrome.label(book, Rect2(86, 22, 764, 45), "セキュリティ運用規則", INK, 30)
	Chrome.panel(book, Rect2(30, 86, 820, 2), Color("34556f"))
	body = Chrome.rich(book, Rect2(30, 110, 820, 480), INK, 20)
	body.focus_mode = Control.FOCUS_ALL
	body.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	for rule in rules:
		body.push_font_size(22)
		body.push_color(GREEN)
		body.add_text(rule.label + "\n")
		body.pop()
		body.pop()
		body.add_text(Information.display(rule.value) + "\n\n")
	close_button = Chrome.button(book, Rect2(30, 620, 820, 42), "閉じる  [ESC]", PAPER)
	close_button.pressed.connect(closed.emit)
	for control in [body, close_button]:
		var other: Control = close_button if control == body else body
		var path: NodePath = control.get_path_to(other)
		control.focus_next = path
		control.focus_previous = path
		control.focus_neighbor_left = path
		control.focus_neighbor_right = path
		control.focus_neighbor_top = path
		control.focus_neighbor_bottom = path
	self.hide()
