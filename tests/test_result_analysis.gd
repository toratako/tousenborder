extends SceneTree
const Analysis = preload("res://src/domain/result_analysis.gd")
const Fixtures = preload("res://tests/fixtures.gd")
const Radar = preload("res://src/ui/results/result_radar.gd")
const View = preload("res://src/ui/results/result_analysis_view.gd")
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)


func sample(complete: bool, bias: String) -> Dictionary:
	var records: Array = []
	for i in 12:
		var expected := "allow" if i < 6 else "block"
		var correct := not ((bias == "allow" and i >= 8) or (bias == "block" and i < 4))
		records.append(
			{
				"category": "file" if i < 6 else "email",
				"ground_truth": expected,
				"level": "intermediate" if i < 6 else "beginner",
				"verdict": expected if correct else ("block" if expected == "allow" else "allow"),
				"correct": correct,
				"missing_evidence": [] if complete or i < 6 else ["policy"],
				"investigation_required": true,
				"observations": [],
			}
		)
	return { "records": records, "elapsed_seconds": 750.0 }


func texts(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children():
		result += texts(child)
	return result


func radar_nodes(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node.get_script() == Radar:
		result.append(node)
	for child in node.get_children():
		result.append_array(radar_nodes(child))
	return result


func _initialize() -> void:
	run.call_deferred()


func profile_sample(count: int, confirmed: int, correct: int) -> Dictionary:
	var records: Array = []
	for i in count:
		records.append(
			{
				"category": "email",
				"ground_truth": "allow" if i % 2 == 0 else "block",
				"correct": i < correct,
				"level": "intermediate",
				"investigation_required": true,
				"missing_evidence": [] if i < confirmed else ["policy"],
				"observations": [],
			}
		)
	return { "records": records, "elapsed_seconds": 600 }


func check_profiles() -> void:
	var old_record := profile_sample(12, 12, 12)
	old_record.records[0].erase("investigation_required")
	var initial_only := profile_sample(12, 12, 12)
	for record in initial_only.records:
		record.investigation_required = false
	for snapshot in [
		profile_sample(1, 1, 1),
		profile_sample(4, 4, 4),
		old_record,
		initial_only,
		{ },
	]:
		var panel := VBoxContainer.new()
		View.profile(panel, Analysis.analyze(snapshot))
		var display := texts(panel)
		check(
			display.contains("セキュリティチャレンジャー") and not display.contains("参考")
			and not display.contains("判定保留") and not display.contains(" × "),
			"少数・旧記録・調査対象不足は級を付けずセキュリティチャレンジャーと表示",
		)
		panel.free()
	var regular := VBoxContainer.new()
	View.profile(regular, Analysis.analyze(profile_sample(10, 10, 10)))
	check(
		texts(regular).contains("慎重型 × プロ級") and not texts(regular).contains("セキュリティチャレンジャー"),
		"十分な記録では既存のスタイルと級を表示",
	)
	regular.free()
	for count in [5, 9]:
		var panel := VBoxContainer.new()
		View.profile(panel, Analysis.analyze(profile_sample(count, count, count)))
		check(
			texts(panel).contains("慎重型 × 実践級") and not texts(panel).contains("セキュリティチャレンジャー"),
			"5～9問でも通常のスタイルと級を表示し、プロ級にはしない",
		)
		panel.free()
	for count in [1, 10]:
		var retry := profile_sample(count, count, count)
		retry.retry_of = "previous-session"
		var panel := VBoxContainer.new()
		View.profile(panel, Analysis.analyze(retry))
		var display := texts(panel)
		check(
			display.contains("復習者") and not display.contains("セキュリティチャレンジャー")
			and not display.contains(" × "),
			"再挑戦は件数や内部判定に関係なく復習者と表示",
		)
		panel.free()
	for pair in [[5, "intuitive"], [6, "middle"], [7, "middle"], [8, "careful"]]:
		check(Analysis.analyze(profile_sample(10, pair[0], 10)).style.id == pair[1], "確認率50・80％と中間の境界")
	for pair in [[6, "beginner"], [7, "practice"]]:
		check(Analysis.analyze(profile_sample(10, 10, pair[0])).level.id == pair[1], "正答率70％の境界")
	check(Analysis.analyze(profile_sample(2, 2, 2)).style.id == "pending", "追加調査2問では保留")
	check(Analysis.analyze(profile_sample(3, 3, 3)).style.id == "careful", "追加調査3問からスタイル判定")
	var short := Analysis.analyze(profile_sample(9, 9, 9))
	check(not short.level.reference and short.level.id == "practice", "9問は通常判定だがプロ級にはしない")
	var source := profile_sample(10, 8, 10)
	var data := Analysis.analyze(source)
	check(data.level.id == "pro" and not data.level.reference, "10問・80％確認・高難度実績でプロ級")
	source.records[0].correct = false
	check(Analysis.analyze(source).level.id == "pro", "正答率90％、安全な対象の誤遮断1件はプロ級条件内")
	source.records[1].correct = false
	check(Analysis.analyze(source).level.id == "practice", "90％未満は実践級")
	source = profile_sample(10, 10, 10)
	source.records[1].correct = false
	check(Analysis.analyze(source).level.id == "practice", "90％でも危険な許可があれば実践級")
	source = profile_sample(10, 10, 10)
	source.records[0].observations = [{ "ok": true, "correct_usage": false }]
	data = Analysis.analyze(source)
	check(data.level.id == "practice" and data.advice.review_indices == [0], "不適切な調査はプロ級を妨げ該当問題を復習")
	source = profile_sample(10, 10, 10)
	for record in source.records:
		record.level = "beginner"
	check(Analysis.analyze(source).level.id == "practice", "初級だけの満点はプロ級にしない")
	for i in 2:
		source.records[i].level = "intermediate"
	check(Analysis.analyze(source).level.id == "practice", "中級正解2問ではプロ級を保留")
	source.records[2].level = "advanced"
	check(Analysis.analyze(source).level.id == "pro", "中級以上正解3問で条件を満たす")
	source.records[3].level = "custom"
	check(Analysis.analyze(source).level.id == "practice", "未知の難易度を高難度扱いしない")
	source = profile_sample(10, 10, 10)
	var known_levels := ["beginner", "intermediate", "advanced"]
	for i in source.records.size():
		source.records[i].level = known_levels[i % known_levels.size()]
	data = Analysis.analyze(source)
	check(
		data.unknown_level == 0 and data.scope.contains("初級") and not data.scope.contains("不明"),
		"超初級・初級の3区分も既存の難易度として認識",
	)
	source = profile_sample(10, 10, 10)
	for record in source.records:
		record.level = "unrated"
	data = Analysis.analyze(source)
	check(
		data.unknown_level == 10 and data.harder_correct == 0
		and data.level.id == "practice" and data.scope.contains("難易度未評価"),
		"未評価問題を高難度実績に数えない",
	)
	source.records[0].category = "custom"
	source.records[0].category_label = "独自の分類"
	check(Analysis.analyze(source).categories.custom.label == "独自の分類", "追加教材の分野名は履歴だけで再現")
	source = profile_sample(100, 100, 100)
	for record in source.records:
		record.level = "beginner"
	for i in 3:
		source.records[i].level = "intermediate"
		source.records[i].correct = false
		source.records[i].ground_truth = "allow"
	check(Analysis.analyze(source).level.id == "practice", "初級正解で高得点でも中級を全問誤った場合はプロ級にしない")
	source = profile_sample(10, 10, 10)
	for record in source.records:
		record.ground_truth = "allow"
	check(Analysis.analyze(source).level.id == "practice", "危険な対象が未出題ならプロ級を保留")
	source = profile_sample(10, 5, 10)
	data = Analysis.analyze(source)
	check(data.style.id == "intuitive" and data.level.id == "practice", "直感型を正答率だけでプロ級にしない")
	check(not data.description.contains("必要な確認を押さえ"), "少ない確認を根拠確認十分と言い換えない")
	source.records[0].erase("investigation_required")
	data = Analysis.analyze(source)
	check(data.style.id == "pending" and data.level.id == "practice", "一部の旧記録が欠けても基礎集計は可能")
	source = profile_sample(10, 10, 10)
	var before := Analysis.analyze(source)
	source.elapsed_seconds = 99999
	source.records[0].observations = [{ "ok": true }, { "ok": true }]
	data = Analysis.analyze(source)
	check(
		data.style.id == before.style.id and data.level.id == before.level.id,
		"時間と操作回数で性格・能力を上下させない",
	)
	source = profile_sample(10, 10, 10)
	source.records[0].correct = false
	data = Analysis.analyze(source)
	check(data.advice.review_indices == [0], "分野の誤答傾向から誤った問題だけへ復習")
	source.records[1].correct = false
	data = Analysis.analyze(source)
	check(data.advice.review_indices == [1], "危険な許可を一般の誤判定より優先")
	source.records[2].observations = [
		{ "ok": true, "correct_usage": false },
		{ "ok": true, "correct_usage": false },
	]
	data = Analysis.analyze(source)
	check(data.advice.review_indices == [2] and data.unsafe == 2, "不適切調査を最優先し同じ問題は重複させない")
	source = profile_sample(1, 1, 0)
	source.records[0].ground_truth = "allow"
	data = Analysis.analyze(source)
	check(
		not data.advice.next.contains("苦手") and not data.advice.next.contains("正しく判断でき"),
		"1問の誤答を苦手と断定せず誤った称賛もしない",
	)
	check(Analysis.analyze(profile_sample(10, 10, 10)).advice.review_indices.is_empty(), "課題がなければ復習問題を捏造しない")


func run() -> void:
	check_profiles()
	for complete in [true, false]:
		for bias in ["allow", "balanced", "block"]:
			var data := sample(complete, bias)
			var copy := data.duplicate(true)
			var result := Analysis.analyze(data)
			check(
				result.style.id == ("careful" if complete else "intuitive"),
				"正誤や判定の偏りをスタイルに混ぜない: " + str(result.style),
			)
			check(data == copy, "保存済みデータを書き換えない")
	var data := sample(false, "allow")
	data.records[0].observations = [
		{ "ok": true },
		{ "ok": false, "correct_usage": false },
		{ "ok": true, "correct_usage": false },
		{ "ok": true, "skipped": true },
	]
	var result := Analysis.analyze(data)
	check(result.correct == 8 and is_equal_approx(result.accuracy, 8.0 / 12), "正答率")
	check(result.false_allow == 4 and result.false_block == 0, "誤判定の内訳")
	var findings := Analysis.radar_findings(result)
	check(
		findings[0].contains("4問") and findings[1].contains("すべて許可") and findings[2].contains("6問"),
		"三角形の横の分析は実際の誤判定と情報不足の件数を示す",
	)
	var empty_findings := Analysis.radar_findings(Analysis.analyze({ }))
	check(
		empty_findings[0].contains("出題されていません") and empty_findings[1].contains("出題されていません")
		and empty_findings[2].contains("ありません"),
		"未出題・記録なしを成功と表現しない",
	)
	check(
		result.complete == 6 and result.operations == 3 and result.skipped == 1
		and result.unsafe == 1 and result.failed == 1,
		"証拠・実行・失敗・見送りを別集計",
	)
	check(result.evaluated_operations == 1, "適否の未設定・実行失敗・送信見送りをレーダーの分母から除外")
	var operation_parts := Analysis.operation_segments(result)
	check(
		operation_parts.map(
			func(item):
				return item.count,
		)
		== [2, 1],
		"調査は適否の設定によらず完了・失敗に集計し、見送りは除外",
	)
	check(
		operation_parts.all(
			func(item):
				return not item.label.contains("未評価"),
		),
		"問題設定の未評価をプレイヤーに表示しない",
	)
	check(result.unsafe == 1, "実行完了の中の不適切な操作は別途判定に残す")
	data.records[1].observations = [{ "ok": true, "correct_usage": true }]
	var with_success := Analysis.analyze(data)
	check(
		Analysis.operation_segments(with_success).map(
			func(item):
				return item.count,
		)
		== [3, 1],
		"適切な調査も含めて操作総数と一致",
	)
	for seconds in [0.0, 0.5, 60.0, 301.0, 636.0, 3601.0, 72000.0]:
		check(
			View.time_scale(seconds) > 0 and View.time_scale(seconds) >= seconds,
			"時間の目盛りが実時間を収める",
		)
	check(View.duration(636) == "10分36秒", "合計時間を分秒で表示")
	var axes := Analysis.radar_metrics(result)
	check(
		axes[0].part == 2 and axes[0].total == 6 and axes[1].part == 6 and axes[1].total == 6,
		"危険検知と安全識別の対象数を区別",
	)
	check(axes.size() == 3 and axes[2].part == 6 and axes[2].total == 12, "必要情報の確認を3つ目の軸にする")
	check(
		axes.all(
			func(axis):
				return axis.label not in ["正答率", "調査の適切さ"],
		),
		"正答率と調査の適切さを図から除外",
	)
	check(
		Analysis.radar_metrics(Analysis.analyze({ })).all(
			func(axis):
				return axis.total == 0,
		),
		"空の結果は3軸とも未評価",
	)
	# 0％を含む輪郭も、不正な多角形を作らず描画できる。
	for values in [[0, 0, 0], [1, 0, 1], [1, 1, 1], [1, -1, 0]]:
		var chart := Control.new()
		chart.set_script(Radar)
		root.add_child(chart)
		var chart_metrics: Array[Dictionary] = []
		for value in values:
			chart_metrics.append(
				{
					"label": "確認",
					"part": maxi(value, 0),
					"total": 0 if value < 0 else 1,
					"unit": "問",
					"hint": "",
				}
			)
		chart.setup(chart_metrics)
		check(
			chart.values.size() == 3 and chart.values[1] == -1.0 if values[1] < 0 else chart
			.values
			.size()
			== 3,
			"三角形の欠測を0点にしない",
		)
		await process_frame
		chart.queue_free()
		await process_frame
	check(
		result.categories.file.correct == 6 and result.categories.network.answered == 0,
		"分野別集計と未出題",
	)
	check(result.advice.next.contains("利用条件"), "不適切な調査への助言を優先")
	data = sample(true, "balanced")
	for record in data.records:
		record.erase("investigation_required")
	check(Analysis.analyze(data).style.id == "pending", "古い履歴の基本分析は可能、診断は保留")
	data = sample(true, "balanced")
	for record in data.records:
		record.investigation_required = false
	check(Analysis.analyze(data).style.id == "pending", "初期情報だけの問題で調査傾向を判定しない")
	data.records.resize(1)
	check(Analysis.analyze(data).style.id == "pending", "1問では診断しない")
	data = sample(true, "balanced")
	for record in data.records:
		record.ground_truth = "allow"
	check(Analysis.analyze(data).style.id == "careful", "スタイルは正解が片側だけでも確認行動から判断")
	check(
		Analysis.analyze({ }).answered == 0 and Analysis.analyze({ }).style.id == "pending",
		"空の結果でもゼロ除算しない",
	)
	data = sample(true, "balanced")
	for record in data.records:
		record.correct = false
	check(Analysis.analyze(data).correct == 0, "全問不正解")
	# 判定の正誤や出題比率が変わってもスタイルは確認行動だけで判断する。
	data = sample(true, "balanced")
	for i in 3:
		data.records[i].correct = false
	for i in range(6, 12):
		data.records[i].correct = false
	data.records.append_array(data.records.slice(6, 12).duplicate(true))
	for i in range(12, 18):
		data.records[i].correct = true
	check(Analysis.analyze(data).style.id == "careful", "出題比率や誤判定で慎重型を変更しない")
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	desk._start_shift()
	for item in desk.shift.cases:
		desk.shift.decide(item.ground_truth)
		desk.next.pressed.emit()
	check(desk.summary_analysis.visible and not desk.summary_review.visible, "勤務終了時は分析を表示")
	for i in 5:
		await process_frame
	var radars := radar_nodes(desk.summary_analysis)
	check(radars.size() == 1, "分析画面にレーダーチャートを表示")
	if not radars.is_empty():
		check(radars[0].values.size() == 3, "三角形の3指標を維持")
		var insights: Control = desk.summary_analysis.find_child("RadarInsights", true, false)
		check(
			insights.get_global_rect().position.x >= radars[0].get_global_rect().end.x + 12,
			"図の右に余白を空けて分析を配置",
		)
		check(
			insights.get_global_rect().end.x <= desk.summary_analysis.get_global_rect().end.x,
			"分析文が右にはみ出さない",
		)
		check(
			texts(insights).contains("根拠をそろえる") and texts(insights).contains("問"),
			"右側に各指標と対象件数を表示",
		)
		desk.summary_analysis.ensure_control_visible(radars[0])
		for i in 2:
			await process_frame
		check(
			radars[0].get_global_rect().end.y <= desk.summary_analysis.get_global_rect().end.y + 1,
			"レーダー全体にスクロールで到達できる",
		)
		for caption in radars[0].captions:
			check(
				caption.get_rect().end.x <= radars[0].size.x
				and caption.get_rect().end.y <= radars[0].size.y,
				"軸ラベルのはみ出しを防ぐ",
			)
		check(
			radars[0].captions[0].get_rect().end.y + 8 <= Radar.CENTER_Y - Radar.RADIUS,
			"上部ラベルと三角形の頂点の間に余白を確保",
		)
		check(radars[0].size.y <= 270 and Radar.RADIUS > 76, "高さの増加を抑えつつ三角形自体を大きくする")
		check(radars[0].captions[2].text.contains("根拠をそろえる"), "確認行動を分かりやすい項目名で表示")
	check(
		desk.summary_analysis.get_h_scroll_bar().max_value <= desk.summary_analysis.size.x,
		"横方向へのはみ出しがない",
	)
	check(not texts(desk.summary_analysis).contains("1問平均"), "時間・調査回数の平均表示を削除")
	check(
		texts(desk.summary_analysis).contains("調査回数")
		and not texts(desk.summary_analysis).contains("調査操作"),
		"調査回数の見出しに統一",
	)
	check(not texts(desk.summary_analysis).contains("今回のスタイル"), "スタイル右上の補足表示を削除")
	var time_scale_label: Label = desk.summary_analysis.find_child("TimeScaleLabel", true, false)
	check(time_scale_label.get_line_count() == 1, "時間の目盛りは1行で読み取れ、カードを縦に押し広げない")
	for link in desk.summary_category_links:
		check(
			link.tooltip_text.contains("正答率") and link.tooltip_text.contains("クリック")
			and not link.tooltip_text.contains("参考"),
			"少数の分野も同じ形式のツールチップを表示",
		)
		check(link.size.x >= desk.summary_analysis.size.x * 0.9, "分野別正答率も全幅で配置")
		desk.summary_analysis.ensure_control_visible(link)
		for i in 2:
			await process_frame
		check(
			link.get_global_rect().end.y <= desk.summary_analysis.get_global_rect().end.y + 1,
			"分野別グラフへスクロールで到達できる",
		)
	desk.summary_analysis.scroll_vertical = 0
	for i in 2:
		await process_frame
	desk.summary_analysis.grab_focus()
	var page := InputEventKey.new()
	page.keycode = KEY_PAGEDOWN
	page.pressed = true
	Input.parse_input_event(page)
	for i in 5:
		await process_frame
	check(desk.summary_analysis.scroll_vertical > 0, "キーボードでも下部の分析へスクロールできる")
	page.pressed = false
	Input.parse_input_event(page)
	check(desk.summary_category_links.size() > 0, "出題分野だけ復習リンクを表示")
	check(HistoryStore.validate(desk.completed_snapshot).is_empty(), "追加記録を含む履歴がスキーマに適合")
	var snapshot: Dictionary = desk.completed_snapshot.duplicate(true)
	check(Analysis.analyze(snapshot).unknown_level == 0, "既存教材の難易度と整合")
	var invalid := snapshot.duplicate(true)
	invalid.records[0].investigation_required = "true"
	check(not HistoryStore.validate(invalid).is_empty(), "調査要否の型を検証")
	check(
		snapshot.records.all(
			func(r):
				return r.has("investigation_required"),
		),
		"新しい判定に調査要否を保存",
	)
	var initial_only: Dictionary = desk.shift.cases[0].duplicate(true)
	initial_only.required_evidence = ["initial_information"]
	var independent_shift := InspectionShift.new()
	independent_shift.start([initial_only])
	independent_shift.decide(initial_only.ground_truth)
	check(not independent_shift.records[0].investigation_required, "初期情報だけで足りる場合は追加調査の対象外として記録")
	initial_only.required_evidence = ["either"]
	initial_only.evidence_alternatives = {
		"either": { "any_of": ["initial_information", "lookup"] }
	}
	independent_shift.start([initial_only])
	independent_shift.decide(initial_only.ground_truth)
	check(not independent_shift.records[0].investigation_required, "代替証拠に初期情報がある場合も除外")
	var expected: Dictionary = snapshot.records[0]
	desk.summary_category_links[0].pressed.emit()
	check(desk.summary_review.visible, "分野別グラフのクリックから復習画面へ移動")
	desk._select_summary_tab(1, expected.category)
	check(desk.summary_review.visible and not desk.summary_analysis.visible, "分野から振り返りへ切替")
	check(desk.summary_review.get_parsed_text().contains(expected.id), "選択分野の問題を表示")
	for record in snapshot.records:
		if record.category != expected.category:
			check(not desk.summary_review.get_parsed_text().contains(record.id), "他の分野を絞込")
	desk.summary_tabs[1].pressed.emit()
	check(
		snapshot.records.all(
			func(r):
				return desk.summary_review.get_parsed_text().contains(r.id),
		),
		"振り返りタブで全件に戻す",
	)
	var review_snapshot := snapshot.duplicate(true)
	for record in review_snapshot.records:
		record.missing_evidence = []
	review_snapshot.records[0].correct = false
	review_snapshot.records[0].verdict = "block" if review_snapshot.records[0].ground_truth == "allow" else "allow"
	desk._display_summary(review_snapshot, true)
	for i in 5:
		await process_frame
	check(is_instance_valid(desk.summary_advice_link), "改善対象があれば該当問題の復習ボタンを表示")
	if is_instance_valid(desk.summary_advice_link):
		desk.summary_advice_link.grab_focus()
		for i in 3:
			await process_frame
		check(
			desk.summary_advice_link.get_global_rect().end.y
			<= desk.summary_analysis.get_global_rect().end.y + 1,
			"復習ボタンへフォーカスするとスクロール追従",
		)
		desk.summary_advice_link.pressed.emit()
		check(
			desk.summary_review.visible
			and desk.summary_review.get_parsed_text().contains(review_snapshot.records[0].id),
			"アドバイスから該当する問題へ移動",
		)
		for record in review_snapshot.records.slice(1):
			check(
				not desk.summary_review.get_parsed_text().contains(record.id),
				"関係のない正解問題を復習リンクに混ぜない",
			)
	desk.summary_tabs[1].pressed.emit()
	check(
		review_snapshot.records.all(
			func(r):
				return desk.summary_review.get_parsed_text().contains(r.id),
		),
		"該当問題の復習後も全件へ戻せる",
	)
	desk.summary_tabs[0].pressed.emit()
	check(
		desk.summary_analysis.visible and desk.summary_tabs.size() == 2
		and desk.summary_tabs[0].text == "分析",
		"分析・振り返りの2タブに戻す",
	)
	var analysis_text := texts(desk.summary_analysis)
	for removed in ["詳しい数値", "良かった点", "次に伸ばせる点", "次の勤務で試すこと", "外周100", "分野から復習", "今回の出題範囲での評価"]:
		check(not analysis_text.contains(removed), "削除した表示が残らない：" + removed)
	check(analysis_text.contains("アドバイス"), "助言の見出しをアドバイスに統一")
	for record in snapshot.records:
		record.erase("investigation_required")
	check(HistoryStore.validate(snapshot).is_empty(), "既存形式の履歴も引き続き有効")
	desk.library.cases.clear()
	desk._display_summary(snapshot, true)
	check(
		texts(desk.summary_analysis).contains("セキュリティチャレンジャー")
		and not texts(desk.summary_analysis).contains("判定保留"),
		"教材がなくても古い履歴をセキュリティチャレンジャーとして表示",
	)
	check(
		texts(desk.summary_analysis).contains("判断力・確認力")
		and not texts(desk.summary_analysis).contains("判断と確認"),
		"図の見出しを判断力・確認力へ変更",
	)
	check(desk.summary_home.text == "勤務履歴へ戻る", "履歴の戻り先を維持")
	snapshot.feedback = { "show_expected": false, "show_reason": false }
	desk._display_summary(snapshot, true)
	var visible_text := texts(desk.summary_analysis)
	check(radar_nodes(desk.summary_analysis).is_empty(), "正解非表示設定では判定内訳をレーダーからも明かさない")
	check(
		not visible_text.contains("危険なものを許可") and not visible_text.contains("今回の審査スタイル")
		and not visible_text.contains("次に意識"),
		"非表示設定をグラフ・助言・診断でも尊重",
	)
	for feedback in [
		{ "show_expected": false, "show_reason": true },
		{ "show_expected": true, "show_reason": false },
	]:
		snapshot.feedback = feedback
		desk._display_summary(snapshot, true)
		var all_text := texts(desk.summary_analysis)
		check(
			not all_text.contains("到達レベル") and not all_text.contains("判定の根拠")
			and not is_instance_valid(desk.summary_advice_link),
			"正解または解説非表示ならプロ級条件・助言の復習リンクからも漏らさない",
		)
	var empty_scroll := ScrollContainer.new()
	empty_scroll.size = Vector2(940, 477)
	root.add_child(empty_scroll)
	View.build(
		empty_scroll,
		Analysis.analyze({ }),
		{ },
		func(_category):
			pass,
		func(_indices):
			pass,
	)
	for i in 5:
		await process_frame
	check(
		texts(empty_scroll).contains("セキュリティチャレンジャー") and texts(empty_scroll).contains("未評価"),
		"空の結果画面では級や得点を捏造しない",
	)
	empty_scroll.queue_free()
	desk.queue_free()
	await process_frame
	print("Result analysis tests: %d failures" % failures)
	quit(1 if failures else 0)
