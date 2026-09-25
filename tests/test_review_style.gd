extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func records_for(correct: int, total: int, confirmed: int, required: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for i in range(total):
		records.append({"correct": i < correct, "required_evidence_count": required if i == 0 else 0,
			"confirmed_evidence_count": confirmed if i == 0 else 0})
	return records

func input_for(shift: InspectionShift, tool: Dictionary) -> Dictionary:
	var facts: Array = shift.current().information.duplicate(true)
	for observation in shift.observations:
		if observation.ok and not observation.get("skipped", false) and observation.get("correct_usage", true):
			facts.append_array(observation.information)
	for fact in facts:
		if Information.accepts(tool, fact):
			var token: Dictionary = fact.duplicate(true)
			token.case_id = shift.current().id
			return token
	return {}

func _initialize() -> void:
	test_classification()
	test_evidence_records()
	test_ui.call_deferred()

func test_classification() -> void:
	check(ReviewStyle.classify([]).is_empty(), "回答なしでは分類しない")
	for correct in [0, 1]:
		check(ReviewStyle.classify(records_for(correct, 1, 0, 0)).id == "basic", "調査証拠なしは基礎判断")
	# 境界の直前・一致・直後と全6タイプを確認する。
	for evidence in [79, 80, 81]:
		for entry in [[49, 2], [50, 1], [51, 1], [79, 1], [80, 0], [81, 0]]:
			var expected: Array = ["analyst", "investigator", "explorer"] if evidence >= 80 else ["intuitive", "challenger", "trainee"]
			var result := ReviewStyle.classify(records_for(entry[0], 100, evidence, 100))
			check(result.id == expected[entry[1]], "分類境界: %d / %d" % [entry[0], evidence])
	var weighted: Array[Dictionary] = [
		{"correct": true, "required_evidence_count": 9, "confirmed_evidence_count": 6},
		{"correct": true, "required_evidence_count": 1, "confirmed_evidence_count": 1},
	]
	check(ReviewStyle.classify(weighted).id == "intuitive", "問題ごとの平均ではなく証拠数の合計で集計")
	var mixed := records_for(1, 5, 1, 1)
	check(ReviewStyle.classify(mixed).id == "explorer", "初期情報のみの問題も正解率には含める")
	var result := ReviewStyle.classify(weighted)
	result.label = "changed"
	check(ReviewStyle.classify(weighted).label == "勘どころをつかむ審査官", "戻り値の変更は定義を汚さない")

func test_evidence_records() -> void:
	var catalog := Fixtures.catalog()
	check(catalog.load_pack(), str(catalog.errors))
	var item: Dictionary = catalog.cases.filter(func(c): return c.id == "FIX-FILE")[0].duplicate(true)
	item.required_evidence = ["initial_information", "format", "document_format"]
	item.evidence_alternatives = {"format": {"any_of": ["file", "readelf"]}}
	var shift := InspectionShift.new()
	var cases: Array[Dictionary] = [item]
	shift.start(cases)
	var file: Dictionary = item.tools[0]
	var readelf: Dictionary = item.tools[1]
	check(not shift.inspect(file).ok, "入力のない調査は失敗")
	var unsafe := file.duplicate(true)
	unsafe.correct_usage = false
	check(shift.inspect(unsafe, input_for(shift, unsafe)).ok, "不適切な調査も実行履歴に残す")
	check(shift.decide(item.ground_truth), "証拠なしでも回答可能")
	check(shift.records[0].required_evidence_count == 2 and shift.records[0].confirmed_evidence_count == 0, "初期情報・失敗・不適切な調査は確認数に加算しない")
	check(not shift.decide(item.ground_truth) and shift.records.size() == 1, "重複判定で記録を増やさない")
	shift.start(cases)
	for tool in [file, readelf, readelf]:
		check(shift.inspect(tool, input_for(shift, tool)).ok, "代替経路と同じ調査の再実行")
	check(shift.decide(item.ground_truth), "代替証拠を取得して判定")
	check(shift.records[0].confirmed_evidence_count == 1, "複数の代替Toolや再実行でも証拠は一件")
	check(shift.advance(), "判定後に進める")
	check(shift.records[0].confirmed_evidence_count == 1, "調査履歴を消しても判定時の証拠数を保持")
	shift.start(cases)
	check(shift.records.is_empty(), "再開始で記録をリセット")
	# 許可された外部照会の実施・見送り・不適切な実施を同じ必須証拠で比較。
	item = catalog.cases.filter(func(c): return c.id == "FIX-HASH")[0].duplicate(true)
	item.required_evidence = ["initial_information", "vt_hash"]
	cases = [item]
	for action in ["skip", "unsafe", "send"]:
		shift.start(cases)
		var hash_tool: Dictionary = item.tools[0]
		check(shift.inspect(hash_tool, input_for(shift, hash_tool)).ok, "外部照会の入力Hashを取得")
		var external: Dictionary = item.external_references[0].duplicate(true)
		if action == "skip":
			check(shift.decline_external(external, input_for(shift, external)), "外部照会を見送り")
		else:
			external.correct_usage = action == "send"
			check(shift.inspect(external, input_for(shift, external)).ok, "外部照会を実施")
		check(shift.decide(item.ground_truth), "外部照会後に判定")
		check(shift.records[0].required_evidence_count == 1, "途中のHash取得は必須証拠数に加算しない")
		check(shift.records[0].confirmed_evidence_count == (1 if action == "send" else 0), "外部証拠の集計: " + action)

func test_ui() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	var file: Dictionary = desk.catalog.cases.filter(func(c): return c.id == "FIX-FILE")[0]
	var basic: Dictionary = desk.catalog.cases.filter(func(c): return c.id == "FIX-VISIBLE-FILE")[0]
	for scenario in ["analyst", "trainee", "basic"]:
		desk._start_shift()
		check(desk.shift.records.is_empty() and not is_instance_valid(desk.summary_overlay), "前勤務の記録と画面をリセット")
		var item: Dictionary = basic if scenario == "basic" else file
		var cases: Array[Dictionary] = [item]
		desk.shift.start(cases)
		if scenario == "analyst":
			desk._inspect(file.tools[0], input_for(desk.shift, file.tools[0]))
			desk._inspect(file.references[0])
		var verdict: String = item.ground_truth
		if scenario == "trainee":
			verdict = "block" if verdict == "allow" else "allow"
		check(desk.shift.decide(verdict), "UIの勤務を判定")
		desk.next.pressed.emit()
		await process_frame
		var style := ReviewStyle.classify(desk.shift.records)
		check(style.id == scenario, "実際の操作から審査スタイルを集計")
		check(desk.summary_style.visible and desk.summary_style.text == "今回の審査スタイル：" + style.label, "勤務結果のタイプ名")
		check(desk.summary_style_message.text == style.message, "勤務結果の一言")
		check(desk.summary_style_message.position.y + desk.summary_style_message.size.y <= desk.summary_review.position.y, "一言と問題の振り返りが重ならない")
		check(desk.summary_review.get_parsed_text().contains(item.explanation), "従来の問題別解説も表示")
	# 全タイプの長い名称・一言でも表示領域に収まることを確認。
	var styles: Array = ReviewStyle.THOROUGH + ReviewStyle.LIMITED + [ReviewStyle.BASIC]
	for style in styles:
		desk.summary_style.text = "今回の審査スタイル：" + style.label
		desk.summary_style_message.text = style.message
		await process_frame
		check(desk.summary_style.position.y + desk.summary_style.size.y <= desk.summary_style_message.position.y, "タイプ名の折り返し領域: " + style.id)
		check(desk.summary_style_message.position.y + desk.summary_style_message.size.y <= desk.summary_review.position.y, "一言の折り返し領域: " + style.id)
	desk.summary_home.pressed.emit()
	check(desk.start_screen.visible and not is_instance_valid(desk.summary_overlay), "タイトル画面へ戻れる")
	desk.queue_free()
	await process_frame
	print("Review style tests: %d failures" % failures)
	quit(1 if failures else 0)
