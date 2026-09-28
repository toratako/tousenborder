extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT
const MUTED = Chrome.MUTED

signal closed
const HOW_TO_SLIDES := [
	"res://assets/how_to/01-target.png",
	"res://assets/how_to/02-tools.png",
	"res://assets/how_to/03-compare.png",
	"res://assets/how_to/04-external.png",
	"res://assets/how_to/05-stamp.png",
	"res://assets/how_to/06-audit.png",
]
var image: TextureRect
var previous_button: Button
var next_button: Button
var close_button: Button
var counter: Label
var index := 0


func setup() -> void:
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.9))
	var sheet := Chrome.panel(self, Rect2(40, 24, 1200, 752), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(28, 16, 500, 40), "遊び方", INK, 26)
	close_button = Chrome.button(sheet, Rect2(980, 16, 192, 40), "閉じる  [ESC]", PAPER)
	close_button.pressed.connect(closed.emit)
	image = TextureRect.new()
	image.position = Vector2(24, 72)
	image.size = Vector2(1152, 600)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(image)
	previous_button = Chrome.button(sheet, Rect2(376, 690, 144, 42), "←  前へ", PAPER)
	next_button = Chrome.button(sheet, Rect2(680, 690, 144, 42), "次へ  →", PAPER)
	previous_button.pressed.connect(change_slide.bind(-1))
	next_button.pressed.connect(change_slide.bind(1))
	counter = Chrome.label(sheet, Rect2(536, 690, 128, 42), "", MUTED, 18)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	self.hide()


func change_slide(direction: int) -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	index = clampi(index + direction, 0, HOW_TO_SLIDES.size() - 1)
	image.texture = load(HOW_TO_SLIDES[index])
	counter.text = "%d / %d" % [index + 1, HOW_TO_SLIDES.size()]
	previous_button.disabled = index == 0
	next_button.disabled = index == HOW_TO_SLIDES.size() - 1
	# 無効になった端のボタンからフォーカスを戻し、Tabをギャラリー内に留める。
	var controls: Array[Button] = [close_button]
	for button in [previous_button, next_button]:
		if not button.disabled:
			controls.append(button)
		elif previous_focus == button:
			close_button.grab_focus()
	for i in range(controls.size()):
		var button := controls[i]
		button.focus_previous = button.get_path_to(
			controls[(i - 1 + controls.size()) % controls.size()]
		)
		button.focus_next = button.get_path_to(controls[(i + 1) % controls.size()])
		button.focus_neighbor_top = button.focus_previous
		button.focus_neighbor_bottom = button.focus_next
