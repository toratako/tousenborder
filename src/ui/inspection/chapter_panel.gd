extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT

signal continued
var body: RichTextLabel
var continue_button: Button


func setup() -> void:
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.85))
	var sheet := Chrome.panel(self, Rect2(260, 120, 760, 560), Color("101e32"), Color("34556f"))
	body = Chrome.rich(sheet, Rect2(30, 28, 700, 430), INK, 20)
	continue_button = Chrome.button(sheet, Rect2(30, 480, 700, 48), "審査を始める", PAPER)
	continue_button.pressed.connect(continued.emit)
	body.focus_mode = Control.FOCUS_ALL
	ScreenLayout.focus_cycle([body, continue_button])
	self.hide()


func present(chapter: Dictionary) -> void:
	body.clear()
	body.add_text(chapter.title + "\n\n" + chapter.intro)
	show()
	continue_button.grab_focus()
