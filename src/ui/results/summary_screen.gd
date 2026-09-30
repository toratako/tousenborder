extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const Verdict = preload("res://src/ui/shared/verdict_presentation.gd")
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
var expanded_reviews: Dictionary = { }
var review_category := ""
var review_indices: Array = []


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
		title.text = ("審査履歴 · 再挑戦 · " if snapshot.has("retry_of") else "審査履歴 · ") + HistoryStore.date_label(
			snapshot.completed_at
		)
		title.add_theme_font_size_override("font_size", 23)
		home.grab_focus()


func _build() -> void:
	ScreenLayout.prepare(self, Color(0.02, 0.04, 0.09, 0.82))
	sheet = Chrome.panel(self, Rect2(140, 40, 1000, 720), Color("101e32"), Color("34556f"))
	title = Chrome.label(sheet, Rect2(30, 18, 940, 45), "審査結果", INK, 30)
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
	review.add_theme_constant_override("line_separation", 4)
	review.add_theme_constant_override("table_h_separation", 0)
	review.add_theme_constant_override("table_v_separation", 0)
	review.meta_clicked.connect(_toggle_review)
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
		home.text = "審査履歴へ戻る"
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
	review_category = category
	review_indices = indices.duplicate()
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
		_review_item(record, feedback, labels, index)


func _review_item(record: Dictionary, feedback: Dictionary, labels: Dictionary, index: int) -> void:
	var color := Chrome.GREEN if record.correct else Chrome.RED
	review.push_table(1)
	review.set_table_column_expand(0, true, 1, false)
	_review_cell(Color("10372f") if record.correct else Color("3c202b"), color.darkened(0.4))
	_review_text(record.title + "\n", 20, INK)
	_review_text("✓ 正解" if record.correct else "✕ 誤判定", 22, color)
	_review_text("   " + Verdict.summary(record, feedback, labels).replace("\n", " "), 17, INK)
	review.pop() # Header cell.
	if feedback.get("show_reason", true):
		_review_cell(Chrome.BACKGROUND, Chrome.BORDER)
		if Verdict.unsafe_investigation(record):
			_review_text("! 調査方法に注意\n", 17, Color("ffbd70"))
		var expanded: bool = expanded_reviews.get(index, false)
		review.push_meta(index)
		_review_text("▼ 理由を閉じる" if expanded else "▶ 理由を表示", 16, Chrome.CYAN)
		review.pop()
		if expanded:
			_review_text("\n\n判定の理由\n", 15, Chrome.CYAN)
			_review_text(record.explanation, 18, INK)
			var investigation := InspectionShift.investigation_feedback(record)
			if not investigation.is_empty():
				_review_text("\n\n調査の振り返り\n", 15, Chrome.CYAN)
				_review_text(investigation, 17, INK)
		review.pop() # Reason cell; height follows the full text.
	review.pop() # Table.
	review.add_text("\n\n")


func _review_cell(fill: Color, border: Color) -> void:
	review.push_cell()
	review.set_cell_row_background_color(fill, fill)
	review.set_cell_border_color(border)
	review.set_cell_padding(Rect2(16, 10, 16, 10))


func _toggle_review(index: Variant) -> void:
	if not index is int or index < 0 or index >= snapshot.records.size():
		return
	var scroll := review.get_v_scroll_bar().value
	expanded_reviews[index] = not expanded_reviews.get(index, false)
	_render_records(review_category, review_indices)
	review.get_v_scroll_bar().set_deferred("value", scroll)


func _review_text(text: String, font_size: int, color: Color) -> void:
	# 教材の文字列は装飾タグとして解釈せず、長文も省略しない。
	review.push_font_size(font_size)
	review.push_color(color)
	review.add_text(text)
	review.pop()
	review.pop()


func show_save_result(saved: bool, error: String) -> void:
	save_notice.text = "" if saved else "履歴を保存できませんでした。"
	save_notice.tooltip_text = error
	retry.visible = not saved
	update_focus()
