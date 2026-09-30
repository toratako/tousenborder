extends RefCounted
const Chrome = preload("res://src/ui/shared/game_theme.gd")
const Analysis = preload("res://src/domain/result_analysis.gd")
const Radar = preload("res://src/ui/results/result_radar.gd")
const MUTED := Color("b0c8da")
const ORANGE := Color("ffbd73")
const RED := Color("ff718b")
const PURPLE := Color("c7b0ff")


static func text(parent: Node, value: String, font_size := 18, color := Chrome.TEXT) -> Label:
	var label := Chrome.label(parent, Rect2(), value, color, font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_constant_override("line_spacing", 4)
	return label


static func section(parent: Node, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := Chrome.box(Color("14263b"), Chrome.BORDER, 16)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	if not title.is_empty():
		text(column, title, 19)
	return column


static func horizontal(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row


static func meter(parent: Node, numerator: int, denominator: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(40, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.value = Analysis.ratio(numerator, denominator) * 100
	bar.add_theme_stylebox_override("background", Chrome.box(Color("070e1b"), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", Chrome.box(Chrome.CYAN, Color.TRANSPARENT, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


static func category_row(parent: Node, category: Dictionary) -> Button:
	var button := Chrome.button(parent, Rect2(), "", Chrome.TEXT)
	button.custom_minimum_size.y = 36
	button.disabled = category.answered == 0
	var row := HBoxContainer.new()
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 9
	row.offset_right = -9
	row.offset_top = 4
	row.offset_bottom = -4
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := text(row, category.label, 16, MUTED if category.answered == 0 else Chrome.TEXT)
	name.size_flags_horizontal = Control.SIZE_FILL
	name.custom_minimum_size.x = 160
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := meter(row, category.correct, category.answered)
	bar.visible = category.answered > 0
	var count := text(
		row,
		"%d / %d問" % [category.correct, category.answered] if category.answered > 0 else "未出題",
		15,
		MUTED,
	)
	count.custom_minimum_size.x = 78
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_horizontal = Control.SIZE_FILL if category.answered > 0 else Control.SIZE_EXPAND_FILL
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if category.answered > 0:
		button.tooltip_text = "%s：正答率 %d％。クリックで問題を振り返る。" % [
			category.label,
			roundi(Analysis.ratio(category.correct, category.answered) * 100),
		]
	else:
		button.tooltip_text = "%s：この審査では出題されていません。" % category.label
	return button


static func segments(parent: Node, items: Array, colors: Array) -> void:
	var track := HBoxContainer.new()
	track.custom_minimum_size.y = 9
	track.add_theme_constant_override("separation", 0)
	parent.add_child(track)
	var total := 0
	for i in items.size():
		var count := int(items[i].count)
		total += count
		if count == 0:
			continue
		var segment := ColorRect.new()
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.size_flags_stretch_ratio = float(count)
		segment.color = colors[i]
		segment.tooltip_text = "%s：%d" % [items[i].label, count]
		track.add_child(segment)
	if total == 0:
		var empty := ColorRect.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.color = Chrome.BORDER
		track.add_child(empty)


static func duration(seconds: float) -> String:
	var whole := floori(seconds)
	return "%d分%02d秒" % [whole / 60, whole % 60]


static func time_scale(seconds: float) -> int:
	var minutes := seconds / 60.0
	var step := 1 if minutes <= 5 else (5 if minutes <= 30 else (10 if minutes <= 60 else 60))
	return maxi(step, ceili(minutes / step) * step) * 60


static func metric_cards(parent: Node, data: Dictionary) -> void:
	var row := horizontal(parent)
	var accuracy := section(row, "正答率")
	var time := section(row, "審査時間")
	var operations := section(row, "調査回数")
	for column in [accuracy, time, operations]:
		column.add_theme_constant_override("separation", 5)
	text(
		accuracy,
		"%d％" % roundi(data.accuracy * 100) if data.answered > 0 else "未評価",
		28,
		Chrome.CYAN,
	)
	segments(
		accuracy,
		[
			{ "label": "正解", "count": data.correct },
			{ "label": "不正解", "count": data.answered - data.correct },
		],
		[Chrome.CYAN, RED],
	)
	text(accuracy, "正解 %d問  /  全%d問" % [data.correct, data.answered], 14, Chrome.CYAN)
	text(time, duration(data.elapsed_seconds), 28, PURPLE)
	var limit := time_scale(data.elapsed_seconds)
	var bar := meter(time, roundi(data.elapsed_seconds), limit)
	bar.name = "TimeRuler"
	bar.add_theme_stylebox_override("fill", Chrome.box(PURPLE, Color.TRANSPARENT, 0))
	bar.tooltip_text = "目盛り：0～%d分（目標時間ではありません）" % (limit / 60)
	var scale := text(time, "0–%d分" % (limit / 60), 12, MUTED)
	scale.name = "TimeScaleLabel"
	scale.autowrap_mode = TextServer.AUTOWRAP_OFF
	scale.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.tooltip_text = "棒は経過時間の目盛りです。目標時間や能力点ではありません。用語集・規則集・遊び方・一時停止・外部送信確認・判定後の時間を除きます。"
	text(operations, "%d回" % data.operations, 28)
	var items := Analysis.operation_segments(data)
	var colors := [MUTED, ORANGE]
	segments(operations, items, colors)
	operations.tooltip_text = "実行完了 %d回 / 実行失敗 %d回。完了は操作が適切だったことを意味しません。資料の再表示と外部送信の見送り%d回は含みません。" % [
		data.operations - data.failed,
		data.failed,
		data.skipped,
	]


static func radar_section(parent: Node, data: Dictionary) -> void:
	var column := section(parent, "判断力・確認力")
	var row := horizontal(column)
	row.add_theme_constant_override("separation", 24)
	var chart := Control.new()
	chart.set_script(Radar)
	row.add_child(chart)
	var axes := Analysis.radar_metrics(data)
	chart.setup(axes)
	var findings := Analysis.radar_findings(data)
	var insights := VBoxContainer.new()
	insights.name = "RadarInsights"
	insights.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insights.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	insights.add_theme_constant_override("separation", 18)
	row.add_child(insights)
	for i in axes.size():
		var axis: Dictionary = axes[i]
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		insights.add_child(item)
		var heading := horizontal(item)
		text(heading, axis.label, 17)
		var count := text(
			heading,
			"%d％  ·  %d/%d問"
			% [roundi(Analysis.ratio(axis.part, axis.total) * 100), axis.part, axis.total] if axis.total
			> 0 else "未評価",
			17,
			Chrome.CYAN if axis.total > 0 else MUTED,
		)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.size_flags_horizontal = Control.SIZE_FILL
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.tooltip_text = axis.hint
		text(item, findings[i], 15, MUTED if axis.part == axis.total else ORANGE)


static func content_list(parent: ScrollContainer) -> VBoxContainer:
	parent.gui_input.connect(_scroll_input.bind(parent))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	parent.add_child(list)
	return list


static func profile(parent: Node, data: Dictionary) -> void:
	var column := section(parent, "")
	column.add_theme_constant_override("separation", 8)
	var basic: bool = (
		data.level.reference or data.style.id == "pending" or data.level.id == "pending"
	)
	var label: String = "復習者" if data.is_retry else (
		"セキュリティチャレンジャー" if basic else data.style.label + " × " + data.level.label
	)
	var result_label := text(column, label, 32, Chrome.CYAN)
	if not basic and not data.is_retry:
		result_label.tooltip_text = data.style.reason + "\n" + data.level.reason
	text(column, "今回の判断と調査を振り返り、次の学習に役立てましょう。" if basic or data.is_retry else data.description, 17)
	text(column, data.scope, 15, MUTED)


static func build(
	parent: ScrollContainer,
	data: Dictionary,
	feedback: Dictionary,
	open_category: Callable,
	open_review: Callable,
) -> Dictionary:
	var links: Array[Button] = []
	var advice_link: Button = null
	var list := content_list(parent)
	if feedback.get("show_expected", true) and feedback.get("show_reason", true):
		profile(list, data)
	metric_cards(list, data)
	if feedback.get("show_expected", true):
		radar_section(list, data)
	var categories := section(list, "分野別の正答率")
	for id in data.categories:
		var button := category_row(categories, data.categories[id])
		if data.categories[id].answered > 0:
			button.pressed.connect(open_category.bind(id))
			links.append(button)
	if feedback.get("show_reason", true) and feedback.get("show_expected", true):
		var action := section(list, "アドバイス")
		text(action, data.advice.next, 17)
		if not data.advice.review_indices.is_empty():
			advice_link = Chrome.button(
				action,
				Rect2(),
				"該当する%d問を復習" % data.advice.review_indices.size(),
				Chrome.CYAN,
			)
			advice_link.custom_minimum_size.y = 36
			advice_link.pressed.connect(open_review.bind(data.advice.review_indices))
	elif feedback.get("show_reason", true):
		text(section(list, "アドバイス"), "問題ごとの結果を確認し、必要な情報と規則を照合してみましょう。", 17)
	return { "categories": links, "advice": advice_link }


static func _scroll_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_PAGEDOWN:
			scroll.scroll_vertical += int(scroll.size.y * 0.8)
		KEY_PAGEUP:
			scroll.scroll_vertical -= int(scroll.size.y * 0.8)
		KEY_HOME:
			scroll.scroll_vertical = 0
		KEY_END:
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		_:
			return
	scroll.accept_event()
