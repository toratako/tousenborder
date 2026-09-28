extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT

signal decided(submit: bool)
var body: RichTextLabel
var send_button: Button
var skip_button: Button


func setup() -> void:
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.9))
	var sheet := Chrome.panel(self, Rect2(280, 120, 720, 560), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(28, 24, 664, 44), "External Reference · 送信前の確認", INK, 25)
	body = Chrome.rich(sheet, Rect2(28, 90, 664, 350), INK, 18)
	skip_button = Chrome.button(sheet, Rect2(28, 480, 320, 48), "送信を見送る  [ESC]", PAPER)
	send_button = Chrome.button(sheet, Rect2(364, 480, 328, 48), "送信して調査", PAPER)
	skip_button.pressed.connect(decided.emit.bind(false))
	send_button.pressed.connect(decided.emit.bind(true))
	for button in [skip_button, send_button]:
		var other: Button = send_button if button == skip_button else skip_button
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)
		button.focus_neighbor_top = button.get_path_to(other)
		button.focus_neighbor_bottom = button.get_path_to(other)
	self.hide()


func present(tool: Dictionary, input: Dictionary) -> void:
	body.text = tool.label + "\n\n送信する情報：" + tool.submission.type + "\n送信内容：" + Information.display(
		input.value
	) + "\n\n" + tool.submission.warning
	if not input.is_empty():
		body.text += "\n\n選んだ入力：" + input.label + "\n" + Information.display(input.value)
	body.scroll_to_line(0)
	show()
