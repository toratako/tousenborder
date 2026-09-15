extends Control
## 表示のみを担当。教材・ツール・判定状態は core/ に分離。

@export_file("*.json") var content_pack := "res://data/intro.json"

const PAPER := Color("d6c9a3")
const INK := Color("30352f")
const MUTED := Color("969c86")
const GREEN := Color("8ba879")
const RED := Color("bc6452")
var catalog := ContentCatalog.new()
var shift := InspectionShift.new()
var workspace: Control
var tool_buttons: Array[Button] = []
var status: Label
var countdown: Label
var countdown_state: Label
var dossier: RichTextLabel
var dossier_title: Label
var dossier_meta: Label
var dossier_caption: Label
var dossier_icon: TextureRect
var stamp: Label
var feedback: Label
var terminal: RichTextLabel
var approve: Button
var deny: Button
var next: Button
var summary: Panel
var summary_overlay: Panel
var summary_title: Label
var summary_stats: Label
var summary_review: RichTextLabel
var summary_restart: Button
var summary_home: Button
var start_screen: Panel
var start_button: Button
var license_button: Button
var license_overlay: Panel
var license_body: RichTextLabel
var license_close: Button
var license_tabs: Array[Button] = []
var license_sections: Array[Dictionary] = []
var playing := false
var audit_overlay: Panel
var audit_heading: Label
var audit_body: RichTextLabel

func _ready() -> void:
	var japanese_theme := Theme.new()
	japanese_theme.default_font = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
	theme = japanese_theme
	_build()
	if not catalog.load_pack(content_pack):
		status.text = "教材の読み込みエラー"
		terminal.text = "\n".join(catalog.errors)
		approve.disabled = true
		deny.disabled = true
		return
	_build_tools()
	var rule_text := "\n\n".join(catalog.rules)
	var rules := _rich(workspace, Rect2(968, 144, 254, 470), INK, 15)
	rules.text = rule_text
	_build_audit()
	_build_start_screen()
	shift.changed.connect(_refresh)
	_show_start_screen()

func _process(delta: float) -> void:
	if not playing:
		return
	shift.tick(delta)
	_refresh_countdown()

func _refresh_countdown() -> void:
	if shift.cases.is_empty():
		countdown.text = "--:--"
		return
	if shift.time_limit_seconds == 0:
		countdown.text = "--:--"
		countdown_state.text = "無制限"
		countdown.add_theme_color_override("font_color", MUTED)
		return
	var seconds := ceili(shift.remaining_seconds)
	countdown.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	countdown_state.text = "終了" if shift.finished() else ("監査中" if shift.judged else "")
	countdown.add_theme_color_override("font_color", RED if seconds <= 30 else Color("eee2ad"))

func _build_start_screen() -> void:
	start_screen = _panel(self, Rect2(0, 0, 1280, 800), Color("202c27"))
	start_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel(start_screen, Rect2(56, 60, 1168, 680), Color("28352d"), Color("56624b"))
	_label(start_screen, Rect2(94, 92, 1092, 25), "電子入境管理  /  審査官研修", MUTED, 16)
	_panel(start_screen, Rect2(94, 135, 1092, 2), Color("56624b"))
	_label(start_screen, Rect2(94, 189, 550, 70), "[ / ] パケットを拝見", PAPER, 44)
	_label(start_screen, Rect2(98, 283, 530, 50), "そのアクセスを、許可しますか。", GREEN, 24)
	_label(start_screen, Rect2(98, 356, 514, 124), "ファイル、プロセス、Webサイト、パケット。\n持ち込まれる対象を調べ、証拠を規則と照合。\n最後に判定してください。", PAPER, 17)
	var briefing := _panel(start_screen, Rect2(711, 189, 439, 328), PAPER, Color("a99c7a"))
	_label(briefing, Rect2(26, 20, 387, 23), "勤務前の手引き", Color("817e64"), 13)
	_label(briefing, Rect2(26, 64, 387, 40), "調査 → 判定 → 監査", INK, 24)
	_label(briefing, Rect2(26, 120, 387, 180), "01  左のツールで証拠を集める\n\n02  審査規則に従って許可・拒否\n\n03  監査票で判断の根拠を確認する", INK, 17)
	var limit_text := "時間制限なし" if catalog.time_limit_seconds == 0 else "制限時間 %02d:%02d" % [catalog.time_limit_seconds / 60, catalog.time_limit_seconds % 60]
	_label(start_screen, Rect2(98, 535, 1040, 28), "全%d案件  /  %s  /  監査票の確認中は時計が止まります" % [catalog.cases.size(), limit_text], MUTED, 16)
	start_button = _button(start_screen, Rect2(98, 602, 514, 60), "勤務を開始  >", PAPER)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_start_shift)
	license_button = _button(start_screen, Rect2(711, 610, 439, 44), "ライセンス・著作権表記", MUTED)
	license_button.pressed.connect(_show_licenses)

func _show_licenses() -> void:
	if playing or not start_screen.visible:
		return
	if not is_instance_valid(license_overlay):
		license_sections = preload("res://scripts/core/license_notices.gd").sections()
		license_overlay = _panel(self, Rect2(0, 0, 1280, 800), Color(0.06, 0.08, 0.07, 0.85))
		license_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		license_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var sheet := _panel(license_overlay, Rect2(180, 55, 920, 690), PAPER, Color("93876b"))
		_label(sheet, Rect2(30, 22, 860, 45), "ライセンス・著作権表記", INK, 30)
		for i in range(license_sections.size()):
			var tab := _button(sheet, Rect2(30 + i * 217, 120, 209, 40), license_sections[i].title, PAPER)
			tab.toggle_mode = true
			tab.pressed.connect(_select_license.bind(i))
			license_tabs.append(tab)
		license_body = _rich(sheet, Rect2(30, 183, 860, 409), INK, 15)
		license_close = _button(sheet, Rect2(30, 620, 860, 42), "タイトル画面に戻る", PAPER)
		license_close.pressed.connect(_close_licenses)
	start_button.disabled = true
	license_button.disabled = true
	_select_license(0)
	license_overlay.show()
	license_close.grab_focus()

func _select_license(index: int) -> void:
	license_body.text = license_sections[index].body
	license_body.scroll_to_line(0)
	for i in range(license_tabs.size()):
		license_tabs[i].set_pressed_no_signal(i == index)

func _close_licenses() -> void:
	license_overlay.hide()
	start_button.disabled = false
	license_button.disabled = false
	license_button.grab_focus()

func _close_summary() -> void:
	if is_instance_valid(summary_overlay):
		summary_overlay.hide()
		summary_overlay.queue_free()
		summary_overlay = null

func _show_start_screen() -> void:
	playing = false
	_close_summary()
	audit_overlay.hide()
	workspace.hide()
	start_screen.show()
	start_button.grab_focus()

func _start_shift() -> void:
	if is_instance_valid(license_overlay) and license_overlay.visible:
		return
	_close_summary()
	start_screen.hide()
	workspace.show()
	playing = true
	shift.start(catalog.cases, catalog.time_limit_seconds)
	approve.grab_focus()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("373831"))
	for y in range(82, 745, 29):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("3c3c33"), 1)
	draw_rect(Rect2(0, 0, 1280, 70), Color("222d2d"))
	draw_rect(Rect2(0, 70, 1280, 4), Color("171f1f"))
	draw_rect(Rect2(333, 74, 8, 671), Color("252b27"))
	draw_rect(Rect2(933, 74, 8, 671), Color("252b27"))

func _build() -> void:
	workspace = Control.new()
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(workspace)
	_label(workspace, Rect2(24, 15, 420, 38), "[ / ]  パケットを拝見", PAPER, 26)
	_panel(workspace, Rect2(500, 7, 330, 56), Color("131f1b"), Color("a89b6c"))
	_label(workspace, Rect2(518, 24, 85, 23), "残り時間", Color("c6b77f"), 14)
	countdown = _label(workspace, Rect2(606, 8, 130, 50), "--:--", Color("eee2ad"), 32)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_state = _label(workspace, Rect2(752, 26, 70, 21), "", MUTED, 12)
	status = _label(workspace, Rect2(951, 24, 300, 26), "準備中", PAPER, 17)
	_label(workspace, Rect2(26, 97, 285, 25), "01   調査ツール", PAPER, 16)
	_panel(workspace, Rect2(24, 593, 294, 135), Color("2b322d"), Color("555e4e"))
	_label(workspace, Rect2(40, 605, 263, 24), "審査官への手引き", GREEN, 14)
	_label(workspace, Rect2(40, 636, 261, 79), "申請を読み、証拠を集める。\n審査規則と照合する。\n最後に判定する。", PAPER, 14)
	_label(workspace, Rect2(359, 97, 550, 26), "02   審査机", PAPER, 16)
	_panel(workspace, Rect2(367, 139, 548, 316), Color("222821"))
	_panel(workspace, Rect2(358, 130, 548, 316), PAPER, Color("a99c7a"))
	dossier_caption = _label(workspace, Rect2(380, 142, 502, 20), "電子入境申請書", Color("8c876f"), 11)
	dossier_icon = TextureRect.new()
	dossier_icon.position = Vector2(380, 175)
	dossier_icon.size = Vector2(60, 60)
	dossier_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dossier_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	workspace.add_child(dossier_icon)
	dossier_title = _label(workspace, Rect2(455, 172, 427, 38), "", INK, 26)
	dossier_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	dossier_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dossier_meta = _label(workspace, Rect2(455, 215, 427, 24), "", Color("6f715c"), 14)
	_panel(workspace, Rect2(380, 249, 502, 2), Color("b2a785"))
	dossier = _rich(workspace, Rect2(380, 262, 502, 136), INK, 15)
	stamp = _label(workspace, Rect2(674, 408, 208, 30), "審査待ち", Color("76725e"), 16)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(workspace, Rect2(358, 468, 560, 21), "調査端末", GREEN, 13)
	_panel(workspace, Rect2(358, 497, 548, 231), Color("172622"), Color("63745b"))
	terminal = _rich(workspace, Rect2(372, 509, 521, 205), GREEN, 14)
	_panel(workspace, Rect2(962, 109, 282, 623), Color("202720"))
	_panel(workspace, Rect2(951, 100, 282, 623), Color("b8b28f"), Color("87856c"))
	_label(workspace, Rect2(968, 113, 252, 23), "03   審査規則", INK, 17)
	_label(workspace, Rect2(968, 638, 254, 60), "通達01 / 基礎研修\nこの勤務の規則に従って判定すること。", Color("555d4d"), 13)
	_panel(workspace, Rect2(0, 745, 1280, 55), Color("202825"))
	_label(workspace, Rect2(24, 759, 303, 25), "電子入境管理", MUTED, 13)
	feedback = _label(workspace, Rect2(359, 752, 568, 43), "対象を調査してから判定してください。", PAPER, 13)
	deny = _button(workspace, Rect2(952, 752, 136, 40), "拒否", RED)
	deny.pressed.connect(func(): shift.decide("deny"))
	approve = _button(workspace, Rect2(1100, 752, 136, 40), "許可", GREEN)
	approve.pressed.connect(func(): shift.decide("approve"))

func _build_tools() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 130)
	scroll.size = Vector2(294, 451)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.add_child(scroll)
	var rack := VBoxContainer.new()
	rack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rack.add_theme_constant_override("separation", 9)
	scroll.add_child(rack)
	for i in range(catalog.tools.size()):
		var tool := catalog.tools[i]
		var button := _button(rack, Rect2(0, 0, 276, 38), ">  " + tool.label, PAPER)
		button.custom_minimum_size.y = 38
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = tool.description + "\n対応対象: " + ", ".join(tool.target_types.map(_type_label))
		button.pressed.connect(func(): shift.inspect(tool))
		tool_buttons.append(button)

func _refresh() -> void:
	_refresh_countdown()
	status.text = "第01勤務   /   %02d件目・全%02d件" % [mini(shift.index + 1, shift.cases.size()), shift.cases.size()]
	audit_overlay.visible = false
	if shift.finished():
		_show_summary()
		return
	var item := shift.current()
	_update_dossier_header(item)
	var lines: PackedStringArray = [item.request, ""]
	for key in item.fields:
		if key in ["サイズ", "SIZE"] or (key in ["ファイル", "FILE"] and item.fields[key] == item.title):
			continue
		lines.append("%s:  %s" % [key, item.fields[key]])
	dossier.text = "\n".join(lines)
	dossier.scroll_to_line(0)
	terminal.text = "> 調査待ち。\n左の一覧から対応するツールを選んでください。\n\nこの案件の調査結果はここに記録されます。"
	if not shift.observations.is_empty():
		var logs: PackedStringArray = []
		for observation in shift.observations:
			logs.append("> %s%s\n%s" % [observation.tool, "" if observation.ok else " [取得不可]", observation.output])
		terminal.text = "\n\n".join(logs)
		terminal.scroll_to_line(terminal.get_line_count())
	for i in range(tool_buttons.size()):
		tool_buttons[i].visible = item.type in catalog.tools[i].target_types
		tool_buttons[i].disabled = shift.judged or not item.type in catalog.tools[i].target_types
	approve.visible = not shift.judged
	deny.visible = not shift.judged
	next.visible = shift.judged
	if shift.judged:
		var record: Dictionary = shift.records.back()
		stamp.text = "許可" if record.verdict == "approve" else "拒否"
		stamp.add_theme_color_override("font_color", Color("426544") if record.verdict == "approve" else Color("a34235"))
		feedback.text = "判定を記録しました。前面の監査票を確認してください。"
		_show_audit(record)
	else:
		stamp.text = "審査待ち"
		stamp.add_theme_color_override("font_color", Color("76725e"))
		feedback.text = "対象を調査してから判定してください。"

func _update_dossier_header(item: Dictionary) -> void:
	dossier_caption.text = "電子入境申請書  /  " + item.id
	dossier_title.text = item.title
	dossier_title.tooltip_text = item.title
	var title_font := dossier_title.get_theme_font("font")
	var font_size := 26
	while font_size > 17 and title_font.get_string_size(item.title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > 427:
		font_size -= 1
	dossier_title.add_theme_font_size_override("font_size", font_size)
	var extension: String = item.title.get_extension().to_lower() if item.type in ["file", "process"] else ""
	var kind := _type_label(item.type)
	if not extension.is_empty():
		kind += "（." + extension + "）"
	var size_text: String = item.fields.get("サイズ", item.fields.get("SIZE", ""))
	if size_text.is_empty() and item.type in ["file", "process"]:
		size_text = "サイズ未記載"
	dossier_meta.text = kind + ("  /  " + size_text if not size_text.is_empty() else "")
	dossier_icon.texture = load("res://assets/icons/" + _icon_name(item.type, extension) + ".svg")
	dossier_icon.tooltip_text = kind

func _icon_name(target_type: String, extension: String) -> String:
	if target_type == "url":
		return "web"
	if target_type == "packet":
		return "packet"
	match extension:
		"exe", "com", "bat", "cmd", "sh", "ps1", "dll":
			return "executable"
		"msi", "pkg", "deb", "rpm":
			return "package"
		"zip", "7z", "rar", "gz", "tar":
			return "archive"
		"png", "jpg", "jpeg", "gif", "webp", "svg":
			return "image"
	return "document"

func _build_audit() -> void:
	# 画面全体で入力を受け止め、監査中の背面操作を防ぐ。
	audit_overlay = _panel(self, Rect2(0, 0, 1280, 800), Color(0.06, 0.08, 0.07, 0.78))
	audit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	audit_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel(audit_overlay, Rect2(312, 131, 680, 540), Color("151d18"))
	var sheet := _panel(audit_overlay, Rect2(300, 119, 680, 540), PAPER, Color("93876b"))
	_label(sheet, Rect2(28, 21, 624, 24), "電子入境管理局  /  内部監査課", INK, 14)
	_label(sheet, Rect2(28, 53, 624, 43), "審査結果  監査票", INK, 30)
	_panel(sheet, Rect2(28, 109, 624, 2), Color("9b9174"))
	audit_heading = _label(sheet, Rect2(28, 126, 624, 34), "", INK, 22)
	audit_body = _rich(sheet, Rect2(28, 177, 624, 275), INK, 17)
	next = _button(sheet, Rect2(28, 475, 624, 42), "確認して次の案件へ  >", PAPER)
	next.pressed.connect(func(): shift.advance())
	audit_overlay.visible = false

func _show_audit(record: Dictionary) -> void:
	audit_heading.text = "監査結果：規則に適合" if record.correct else "監査結果：誤判定を指摘"
	audit_heading.add_theme_color_override("font_color", Color("426544") if record.correct else Color("a34235"))
	audit_body.text = "案件番号：%s　/　%s\nあなたの判定：%s　　正しい判定：%s\n調査記録：%d件\n\n監査所見\n%s" % [
		record.id, record.title, _verdict_label(record.verdict),
		_verdict_label(record.expected), record.observations.size(), record.explanation]
	audit_body.scroll_to_line(0)
	next.text = "確認して勤務を終了  >" if shift.index == shift.cases.size() - 1 else "確認して次の案件へ  >"
	audit_overlay.show()
	next.grab_focus()

func _show_summary() -> void:
	if is_instance_valid(summary_overlay):
		return
	for button in tool_buttons:
		button.disabled = true
	summary_overlay = _panel(self, Rect2(0, 0, 1280, 800), Color(0.06, 0.08, 0.07, 0.82))
	summary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel(summary_overlay, Rect2(252, 97, 800, 630), Color("151d18"))
	summary = _panel(summary_overlay, Rect2(240, 85, 800, 630), PAPER, Color("93876b"))
	summary_title = _label(summary, Rect2(30, 22, 740, 45), "時間切れ / 勤務結果" if shift.timed_out else "勤務結果", INK, 30)
	summary_stats = _label(summary, Rect2(30, 77, 740, 30), "正解 %d件  /  誤判定 %d件  /  未審査 %d件" % [shift.score(), shift.records.size() - shift.score(), shift.cases.size() - shift.records.size()], INK, 18)
	_panel(summary, Rect2(30, 119, 740, 2), Color("a99c7a"))
	summary_review = _rich(summary, Rect2(30, 137, 740, 396), INK, 15)
	for record in shift.records:
		_summary_item(record.title, record.id, "正解" if record.correct else "誤判定",
			"あなたの判定：%s　/　正しい判定：%s\n%s" % [
			_verdict_label(record.verdict), _verdict_label(record.expected), record.explanation],
			Color("426544") if record.correct else Color("a34235"))
	for i in range(shift.records.size(), shift.cases.size()):
		_summary_item(shift.cases[i].title, shift.cases[i].id, "未審査", "時間切れのため、判定は記録されていません。", Color("77715a"))
	summary_home = _button(summary, Rect2(30, 557, 280, 45), "スタート画面へ", MUTED)
	summary_home.pressed.connect(_show_start_screen)
	summary_restart = _button(summary, Rect2(326, 557, 444, 45), "新しい勤務を開始", PAPER)
	summary_restart.pressed.connect(_start_shift)
	next.visible = false
	approve.visible = false
	deny.visible = false
	feedback.text = "勤務終了。案件を振り返るか、新しい勤務を開始してください。"
	summary_restart.grab_focus()

func _summary_item(title: String, id: String, result: String, body: String, color: Color) -> void:
	# 教材の文字列を装飾タグとして解釈せず、案件名だけを大きく表示する。
	summary_review.push_font_size(22)
	summary_review.add_text(title + "\n")
	summary_review.pop()
	summary_review.push_color(color)
	summary_review.add_text("%s  /  %s\n" % [id, result])
	summary_review.pop()
	summary_review.add_text(body + "\n\n")

func _panel(parent: Node, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
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

func _label(parent: Node, rect: Rect2, value: String, color: Color, font_size: int) -> Label:
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

func _rich(parent: Node, rect: Rect2, color: Color, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_color_override("default_color", color)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.selection_enabled = true
	parent.add_child(label)
	return label

func _button(parent: Node, rect: Rect2, value: String, color: Color) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("465044") if state in ["hover", "focus"] else Color("29332d")
		style.border_color = color.darkened(0.65) if state == "disabled" else color
		style.set_border_width_all(2)
		style.content_margin_left = 12
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Color("e8dfc7"))
	button.add_theme_color_override("font_disabled_color", Color("606859"))
	parent.add_child(button)
	return button

func _type_label(id: String) -> String:
	return {"process": "プロセス", "file": "ファイル", "url": "Webサイト（URL）", "packet": "パケット"}.get(id, id)

func _verdict_label(id: String) -> String:
	return {"approve": "許可", "deny": "拒否"}.get(id, id)
