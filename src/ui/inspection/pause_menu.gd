extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT
const MUTED = Chrome.MUTED

signal resume_requested
signal restart_requested
signal home_requested
const TITLE_FONT = preload("res://assets/fonts/YuseiMagic-Regular.ttf")
const GAME_TITLE := "とーせんぼ～だ～"
var resume_button: Button
var restart_button: Button
var home_button: Button


func setup() -> void:
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.78))
	var sheet := Chrome.panel(self, Rect2(330, 155, 620, 490), Color("101e32"), Color("34556f"))
	var menu_title := Chrome.label(sheet, Rect2(36, 28, 548, 45), GAME_TITLE, INK, 30)
	menu_title.add_theme_font_override("font", TITLE_FONT)
	resume_button = Chrome.button(sheet, Rect2(36, 151, 548, 52), "ゲームに戻る  [ESC]", PAPER)
	resume_button.pressed.connect(resume_requested.emit)
	restart_button = Chrome.button(sheet, Rect2(36, 225, 548, 52), "勤務を最初からやり直す", PAPER)
	restart_button.pressed.connect(restart_requested.emit)
	home_button = Chrome.button(sheet, Rect2(36, 299, 548, 52), "タイトル画面に戻る", MUTED)
	home_button.pressed.connect(home_requested.emit)
	# 背面を表示したまま、キーボードのフォーカスをメニュー内に留める。
	var menu_actions: Array[Button] = [resume_button, restart_button, home_button]
	for i in range(menu_actions.size()):
		var button := menu_actions[i]
		var previous_path := button.get_path_to(menu_actions[(i + 2) % 3])
		var next_path := button.get_path_to(menu_actions[(i + 1) % 3])
		button.focus_previous = previous_path
		button.focus_next = next_path
		button.focus_neighbor_top = previous_path
		button.focus_neighbor_bottom = next_path
		button.focus_neighbor_left = previous_path
		button.focus_neighbor_right = next_path
	self.hide()
