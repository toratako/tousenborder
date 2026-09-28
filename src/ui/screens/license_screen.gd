extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT

signal closed
var body: RichTextLabel
var close_button: Button
var tabs: Array[Button] = []
var sections: Array[Dictionary] = []


func setup() -> void:
	sections = preload("res://src/ui/screens/license_notices.gd").sections()
	_build()


func _build() -> void:
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.85))
	var sheet := Chrome.panel(self, Rect2(180, 55, 920, 690), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(30, 22, 860, 45), "ライセンス・著作権表記", INK, 30)
	for i in range(sections.size()):
		var tab := Chrome.button(sheet, Rect2(30 + i * 217, 120, 209, 40), sections[i].title, PAPER)
		tab.toggle_mode = true
		tab.pressed.connect(select_license.bind(i))
		tabs.append(tab)
	body = Chrome.rich(sheet, Rect2(30, 183, 860, 409), INK, 15)
	close_button = Chrome.button(sheet, Rect2(30, 620, 860, 42), "タイトル画面に戻る", PAPER)
	close_button.pressed.connect(closed.emit)


func select_license(index: int) -> void:
	body.text = sections[index].body
	body.scroll_to_line(0)
	for i in range(tabs.size()):
		tabs[i].set_pressed_no_signal(i == index)
