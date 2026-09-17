extends SceneTree
## 未判定で時間切れになった調査を、判定の採点と分離して保存・表示する。
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("失敗: " + message)

func _initialize() -> void:
	_run.call_deferred()

func submit_external(desk, item: Dictionary) -> void:
	var tool: Dictionary = item.external_references[0]
	var button: ToolInput = desk.tool_buttons.filter(func(b): return b.tool.id == tool.id)[0]
	var input: Dictionary = {}
	for card in desk.cards:
		for token in card.tokens:
			if Information.accepts(tool, token.payload()):
				input = token.payload()
	check(not input.is_empty(), "実際のカードから送信情報を取得")
	var before: int = desk.shift.observations.size()
	button._drop_data(Vector2.ZERO, {"kind": "information", "information": input})
	check(desk.external_preview.visible and desk.shift.observations.size() == before, "外部送信前に確認画面を表示")
	desk._process(1)
	check(not desk.shift.timed_out, "確認中は時間切れにならない")
	desk.external_send.pressed.emit()
	check(not desk.external_preview.visible and desk.shift.observations.size() == before + 1, "確認後に調査を記録")

func _run() -> void:
	var desk = load("res://scenes/main.tscn").instantiate()
	root.add_child(desk)
	await process_frame
	# 各案件のIDを変え、調査済みの未判定案件と未訪問案件を区別する。
	var item: Dictionary = desk.catalog.cases.filter(func(c): return c.id == "FILE-WIN-ADVANCED-001")[0]
	var future: Dictionary = desk.catalog.cases.filter(func(c): return c.id == "FILE-WIN-VERY-BEGINNER-001")[0]
	var cases: Array[Dictionary] = [item, future]
	for hide_reason in [false, true]:
		desk.catalog.feedback = {"show_reason": not hide_reason, "show_expected": false}
		desk._start_shift()
		desk.shift.start(cases, 1)
		submit_external(desk, item)
		check(desk.shift.unsafe_investigations() == 1, "未判定でも実施済み調査を集計")
		desk._process(1)
		check(desk.shift.timed_out and desk.shift.records.is_empty() and desk.shift.score() == 0, "時間切れは判定を追加しない")
		check(desk.summary_stats.text.contains("未審査 2件") and desk.summary_stats.text.contains("不適切な調査 1件"), "未審査と不適切な調査を別集計")
		var review: String = desk.summary_review.get_parsed_text()
		check(review.count("未審査") == 2, "未訪問案件も未審査のまま")
		check(review.count("不適切な利用") == (0 if hide_reason else 1), "調査所見は表示設定に従い一度だけ表示")
		check(not review.contains("正しい判定") and not review.contains(item.explanation), "未判定案件に正解や判定所見を追加しない")
		check(not review.substr(review.find(future.title)).contains("調査手段の振り返り"), "未訪問案件に調査所見を転記しない")
		if not hide_reason:
			check(review.contains(item.external_references[0].reason), "実施した不適切な調査の理由を表示")
	# 判定済みの履歴と現在の調査を二重計上しない。
	desk.catalog.feedback = {}
	desk._start_shift()
	var judged_item := item.duplicate(true)
	judged_item.required_evidence = []
	var judged_cases: Array[Dictionary] = [judged_item, future]
	desk.shift.start(judged_cases, 1)
	submit_external(desk, judged_item)
	check(desk.shift.decide(judged_item.ground_truth), "判定済みの比較用案件を記録")
	check(desk.shift.score() == 1 and desk.shift.unsafe_investigations() == 1, "判定直後も調査は一件")
	desk.next.pressed.emit()
	desk._process(1)
	check(desk.shift.records.size() == 1 and desk.shift.score() == 1 and desk.shift.unsafe_investigations() == 1, "次の案件で時間切れでも二重計上しない")
	check(desk.summary_review.get_parsed_text().count("不適切な利用") == 1, "判定済み所見は一度だけ表示")
	desk.summary_restart.pressed.emit()
	check(desk.shift.observations.is_empty() and desk.shift.records.is_empty() and desk.shift.unsafe_investigations() == 0 and not desk.shift.timed_out, "リスタートで調査・判定・時間切れをリセット")
	desk.queue_free()
	await process_frame
	print("時間切れの調査フィードバック: 失敗 %d件" % failures)
	quit(1 if failures else 0)
