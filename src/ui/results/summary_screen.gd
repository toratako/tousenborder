extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT
const MUTED = Chrome.MUTED
const RED = Chrome.RED

const Analysis = preload("res://src/domain/result_analysis.gd")
const AnalysisView = preload("res://src/ui/results/result_analysis_view.gd")
signal back_requested
signal retry_wrong_requested
signal restart_requested
signal save_requested
var sheet: Panel
var title: Label
var stats: Label
var review: RichTextLabel
var analysis: ScrollContainer
var advice_link: Button
var tabs: Array[Button] = []
var category_links: Array[Button] = []
var restart: Button
var home: Button
var save_notice: Label
var retry: Button
var snapshot: Dictionary = { }
var from_history := false
var retry_wrong: Button


func setup(data: Dictionary, history: bool, retry_count: int, retry_reason: String) -> void:
	snapshot = data.duplicate(true)
	from_history = history
	_build()
	var report := Analysis.analyze(snapshot)
	var controls := AnalysisView.build(
		analysis,
		report,
		snapshot.feedback,
		func(category: String):
			select_tab(1, category),
		func(indices: Array):
			select_tab(1, "", indices),
	)
	category_links = controls.categories
	advice_link = controls.advice
	_render_records()
	_build_actions(retry_count, retry_reason)
	select_tab(0)
	if snapshot.has("retry_of"):
		title.text = "再挑戦の結果"
	if from_history:
		title.text = ("勤務履歴 · 再挑戦 · " if snapshot.has("retry_of") else "勤務履歴 · ") + HistoryStore.date_label(
			snapshot.completed_at
		)
		title.add_theme_font_size_override("font_size", 23)
		home.grab_focus()


func _build() -> void:
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.82))
	sheet = Chrome.panel(self, Rect2(140, 40, 1000, 720), Color("101e32"), Color("34556f"))
	title = Chrome.label(sheet, Rect2(30, 18, 940, 45), "勤務結果", INK, 30)
	var totals: Dictionary = snapshot.stats
	stats = Chrome.label(
		sheet,
		Rect2(30, 65, 940, 30),
		"正解 %d件  /  誤判定 %d件" % [totals.correct, totals.answered - totals.correct],
		MUTED,
		18,
	)
	stats.text += "  /  不適切な調査 %d件" % totals.unsafe
	stats.add_theme_font_size_override("font_size", 16)
	stats.hide()
	tabs.clear()
	for i in 2:
		var tab := Chrome.button(
			sheet,
			Rect2(30 + i * 475, 72, 465, 40),
			["分析", "問題ごとの振り返り"][i],
			PAPER,
		)
		tab.toggle_mode = true
		tab.pressed.connect(select_tab.bind(i))
		tabs.append(tab)
	analysis = ScrollContainer.new()
	analysis.position = Vector2(30, 128)
	analysis.size = Vector2(940, 477)
	analysis.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	analysis.follow_focus = true
	analysis.focus_mode = Control.FOCUS_ALL
	sheet.add_child(analysis)
	review = Chrome.rich(sheet, Rect2(30, 128, 940, 477), INK, 18)
	review.focus_mode = Control.FOCUS_ALL
	save_notice = Chrome.label(sheet, Rect2(30, 620, 670, 27), "", RED, 15)
	retry = Chrome.button(sheet, Rect2(730, 616, 240, 32), "保存を再試行", PAPER)
	retry.pressed.connect(save_requested.emit)
	retry.hide()


func _build_actions(retry_count: int, retry_reason: String) -> void:
	home = Chrome.button(sheet, Rect2(30, 660, 230, 45), "スタート画面へ", MUTED)
	retry_wrong = Chrome.button(
		sheet,
		Rect2(276, 660, 370, 45),
		"誤った問題に再挑戦（%d問）" % retry_count,
		PAPER,
	)
	retry_wrong.add_theme_font_size_override("font_size", 19)
	retry_wrong.disabled = retry_count == 0
	retry_wrong.tooltip_text = retry_reason
	retry_wrong.pressed.connect(retry_wrong_requested.emit)
	if from_history:
		home.text = "勤務履歴へ戻る"
		home.pressed.connect(back_requested.emit)
		return
	home.pressed.connect(back_requested.emit)
	restart = Chrome.button(sheet, Rect2(662, 660, 308, 45), "同じ問題に再挑戦", PAPER)
	restart.pressed.connect(restart_requested.emit)


func select_tab(index: int, category: String = "", indices: Array = []) -> void:
	analysis.visible = index == 0
	review.visible = index == 1
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == index)
	if index == 1:
		_render_records(category, indices)
		review.scroll_to_line(0)
		tabs[1].grab_focus()
	update_focus()


func update_focus() -> void:
	var controls: Array[Control] = []
	for tab in tabs:
		controls.append(tab)
	if analysis.visible:
		controls.append(analysis)
		for link in category_links:
			controls.append(link)
		if is_instance_valid(advice_link):
			controls.append(advice_link)
	else:
		controls.append(review)
	if retry.visible:
		controls.append(retry)
	controls.append(home)
	if not retry_wrong.disabled:
		controls.append(retry_wrong)
	if not from_history:
		controls.append(restart)
	ScreenLayout.focus_cycle(controls)


func _render_records(category: String = "", indices: Array = []) -> void:
	review.clear()
	if not indices.is_empty():
		review.add_text("アドバイスに関連する問題（全件表示は上の振り返りタブ）\n\n")
	elif not category.is_empty():
		review.add_text(
			str(Analysis.CATEGORY_LABELS.get(category, category)) + "の結果（全件表示は上の振り返りタブ）\n\n"
		)
	var feedback: Dictionary = snapshot.feedback
	var labels: Dictionary = snapshot.action_labels
	for index in snapshot.records.size():
		var record: Dictionary = snapshot.records[index]
		if not indices.is_empty() and not index in indices:
			continue
		if not category.is_empty() and record.category != category:
			continue
		_review_item(
			record.title,
			record.id,
			"正解" if record.correct else "誤判定",
			"あなたの判定：" + labels[record.verdict]
			+ (" / 正しい判定：" + labels[record.ground_truth] if feedback.show_expected else "")
			+ (
				"\n" + record.explanation + "\n" + InspectionShift.investigation_feedback(record) if feedback.show_reason else ""
			),
			Color("57edc2") if record.correct else Color("ff718b"),
		)


func _review_item(title: String, id: String, result: String, body: String, color: Color) -> void:
	# 教材の文字列を装飾タグとして解釈せず、案件名だけを大きく表示する。
	review.push_font_size(22)
	review.add_text(title + "\n")
	review.pop()
	review.push_color(color)
	review.add_text("%s  /  %s\n" % [id, result])
	review.pop()
	review.add_text(body + "\n\n")


func show_save_result(saved: bool, error: String) -> void:
	save_notice.text = "" if saved else "履歴を保存できませんでした。"
	save_notice.tooltip_text = error
	retry.visible = not saved
	update_focus()
