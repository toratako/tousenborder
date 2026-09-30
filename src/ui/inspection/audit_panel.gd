extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const Verdict = preload("res://src/ui/shared/verdict_presentation.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT

signal continued
var heading: Label
var problem_title: Label
var verdict_summary: Label
var result_banner: Panel
var investigation_notice: Label
var body: RichTextLabel
var next_button: Button


func setup() -> void:
	# 画面全体で入力を受け止め、監査中の背面操作を防ぐ。
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.78))
	var sheet := Chrome.panel(self, Rect2(190, 70, 900, 660), Chrome.SURFACE, Chrome.BORDER)
	var title := Chrome.label(sheet, Rect2(64, 16, 772, 48), "審査結果", INK, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Chrome.panel(sheet, Rect2(64, 70, 772, 1), Chrome.BORDER)
	result_banner = Chrome.panel(sheet, Rect2(64, 154, 772, 144), Chrome.BACKGROUND)
	heading = Chrome.label(result_banner, Rect2(20, 2, 732, 58), "", INK, 34)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.max_lines_visible = 1
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	verdict_summary = Chrome.label(result_banner, Rect2(20, 64, 732, 74), "", INK, 21)
	verdict_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	problem_title = Chrome.label(sheet, Rect2(64, 76, 772, 68), "", INK, 22)
	problem_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	problem_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	problem_title.max_lines_visible = 2
	problem_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Chrome.panel(sheet, Rect2(64, 306, 772, 1), Chrome.BORDER)
	investigation_notice = Chrome.label(sheet, Rect2(64, 314, 772, 34), "! 調査方法に注意", Color("ffbd70"), 20)
	body = Chrome.rich(sheet, Rect2(64, 326, 772, 248), INK, 21)
	body.add_theme_constant_override("line_separation", 7)
	body.focus_mode = Control.FOCUS_ALL
	body.add_theme_stylebox_override("focus", Chrome.box(Color.TRANSPARENT, Chrome.CYAN))
	next_button = Chrome.button(sheet, Rect2(255, 598, 390, 42), "次の案件へ  >", PAPER)
	ScreenLayout.focus_cycle([body, next_button])
	next_button.pressed.connect(continued.emit)
	self.visible = false


func present(
	record: Dictionary,
	feedback: Dictionary,
	actions: Array[Dictionary],
	last_case: bool,
) -> void:
	var unsafe := Verdict.unsafe_investigation(record)
	heading.text = "✓ 正解" if record.correct else "✕ 誤判定"
	result_banner.add_theme_stylebox_override("panel", Chrome.box(
		Color("10372f") if record.correct else Color("3c202b"),
		Chrome.GREEN if record.correct else Chrome.RED
	))
	var labels := { }
	for action in actions:
		labels[action.id] = action.label
	verdict_summary.text = Verdict.summary(record, feedback, labels)
	investigation_notice.visible = unsafe and feedback.get("show_reason", true)
	body.position.y = 354 if investigation_notice.visible else 326
	body.size.y = 574 - body.position.y
	heading.tooltip_text = heading.text
	heading.add_theme_color_override(
		"font_color",
		Color("57edc2") if record.correct else Color("ff718b"),
	)
	problem_title.text = record.title
	problem_title.tooltip_text = record.title
	body.clear()
	body.visible = feedback.get("show_reason", true)
	ScreenLayout.focus_cycle([body, next_button] if body.visible else [next_button])
	if feedback.get("show_reason", true):
		_section("判定の理由", Chrome.CYAN)
		body.add_text(record.explanation)
		var investigation := InspectionShift.investigation_feedback(record)
		if not investigation.is_empty():
			body.add_text("\n\n")
			_section("調査の振り返り", Chrome.CYAN)
			if unsafe:
				body.push_color(Color("ffbd70"))
				body.add_text("注意：不適切な調査がありました。\n")
				body.pop()
			body.add_text(investigation)
	next_button.show()
	body.scroll_to_line(0)
	next_button.text = "審査を終了  >" if last_case else "次の案件へ  >"
	self.show()
	next_button.grab_focus()


func _section(text: String, color: Color) -> void:
	body.push_color(color)
	body.push_font_size(22)
	body.add_text(text + "\n")
	body.pop()
	body.pop()
