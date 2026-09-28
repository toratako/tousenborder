extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
## 長時間の調査と判定後のフィードバックを検証する。
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("失敗: " + message)

func _initialize() -> void:
	_run.call_deferred()

func submit_external(desk, item: Dictionary) -> void:
	var tool: Dictionary = Fixtures.resources(item, "external_references")[0]
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
	var elapsed: float = desk.shift.elapsed_seconds
	desk._process(1)
	check(desk.shift.elapsed_seconds == elapsed, "送信確認中は計測停止")
	desk.external_send.pressed.emit()
	check(not desk.external_preview.visible and desk.shift.observations.size() == before + 1, "確認後に調査を記録")

func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	desk.set_process(false)
	# 異なる案件を使い、調査所見が他の案件に混入しないことを確認する。
	var item: Dictionary = desk.library.cases.filter(func(c): return c.id == "FIX-PRIVATE-FILE")[0]
	var future: Dictionary = desk.library.cases.filter(func(c): return c.id == "FIX-VISIBLE-FILE")[0]
	var cases: Array[Dictionary] = [item, future]
	for hide_reason in [false, true]:
		desk.feedback = {"show_reason": not hide_reason, "show_expected": false}
		desk._start_shift()
		desk.shift.start(cases)
		submit_external(desk, item)
		check(desk.shift.unsafe_investigations() == 1, "未判定でも実施済み調査を集計")
		desk._process(10000)
		check(not desk.shift.finished() and desk.shift.elapsed_seconds == 10000, "長時間経過しても調査を継続")
		check(desk.shift.records.is_empty() and desk.shift.score() == 0, "経過時間は判定に影響しない")
		for case in cases:
			check(desk.shift.decide(case.ground_truth), "調査後に判定可能")
			desk.next.pressed.emit()
		check(desk.shift.finished(), "全案件の判定後に終了")
		check(desk.summary_stats.text.contains("不適切な調査 1件"), "不適切な調査を集計")
		var review: String = desk.summary_review.get_parsed_text()
		check(review.count("不適切な利用") == (0 if hide_reason else 1), "調査所見は表示設定に従い一度だけ表示")
		check(not review.contains("正しい判定"), "正解表示設定を保持")
		check(not review.substr(review.find(future.title)).contains("不適切な利用"), "他の案件に調査所見を転記しない")
		if not hide_reason:
			check(review.contains(Fixtures.resources(item, "external_references")[0].reason), "実施した不適切な調査の理由を表示")
	# 判定済みの履歴と現在の調査を二重計上しない。
	desk.feedback = {}
	desk._start_shift()
	var judged_item := item.duplicate(true)
	judged_item.required_evidence = []
	var judged_cases: Array[Dictionary] = [judged_item, future]
	desk.shift.start(judged_cases)
	submit_external(desk, judged_item)
	check(desk.shift.decide(judged_item.ground_truth), "判定済みの比較用案件を記録")
	check(desk.shift.score() == 1 and desk.shift.unsafe_investigations() == 1, "判定直後も調査は一件")
	desk.next.pressed.emit()
	desk._process(1)
	check(desk.shift.records.size() == 1 and desk.shift.score() == 1 and desk.shift.unsafe_investigations() == 1, "次の案件でも二重計上しない")
	check(desk.shift.decide(future.ground_truth) and desk.shift.advance(), "全案件を完了")
	check(desk.summary_review.get_parsed_text().count("不適切な利用") == 1, "判定済み所見は一度だけ表示")
	desk.summary_restart.pressed.emit()
	check(desk.shift.observations.is_empty() and desk.shift.records.is_empty() and desk.shift.unsafe_investigations() == 0 and desk.shift.elapsed_seconds == 0, "リスタートで調査・判定・経過時間をリセット")
	desk.queue_free()
	await process_frame
	print("経過時間と調査フィードバック: 失敗 %d件" % failures)
	quit(1 if failures else 0)
