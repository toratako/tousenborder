extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT

signal continued
var heading: Label
var body: RichTextLabel
var next_button: Button


func setup() -> void:
	# 画面全体で入力を受け止め、監査中の背面操作を防ぐ。
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.78))
	Chrome.panel(self, Rect2(312, 131, 680, 540), Color("050a12"))
	var sheet := Chrome.panel(self, Rect2(300, 119, 680, 540), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(28, 28, 624, 43), "審査結果  監査票", INK, 30)
	Chrome.panel(sheet, Rect2(28, 84, 624, 2), Color("34556f"))
	heading = Chrome.label(sheet, Rect2(28, 101, 624, 34), "", INK, 22)
	body = Chrome.rich(sheet, Rect2(28, 152, 624, 300), INK, 17)
	next_button = Chrome.button(sheet, Rect2(28, 475, 624, 42), "確認して次の案件へ  >", PAPER)
	next_button.pressed.connect(continued.emit)
	self.visible = false


func present(
	record: Dictionary,
	feedback: Dictionary,
	actions: Array[Dictionary],
	last_case: bool,
) -> void:
	heading.text = (
		feedback.get("correct_heading", "監査結果：規則に適合")
		if record.correct
		else feedback.get("incorrect_heading", "SECURITY VIOLATION · 誤判定")
	)
	heading.add_theme_color_override(
		"font_color",
		Color("57edc2") if record.correct else Color("ff718b"),
	)
	body.text = "案件番号：%s / %s\nあなたの判定：%s\n調査操作数：%d件" % [
		record.id,
		record.title,
		_verdict_label(record.verdict, actions),
		record.observations.size(),
	]
	if feedback.get("show_expected", true):
		body.text += "\n正しい判定：" + _verdict_label(record.ground_truth, actions)
	if feedback.get("show_reason", true):
		body.text += "\n\n監査所見\n" + InspectionShift.review_text(record)
	next_button.show()
	body.scroll_to_line(0)
	next_button.text = "勤務を終了  >" if last_case else "次の案件へ  >"
	self.show()
	next_button.grab_focus()


func _verdict_label(id: String, actions: Array[Dictionary]) -> String:
	for action in actions:
		if action.id == id:
			return action.label
	return id
