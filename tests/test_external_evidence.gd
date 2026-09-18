extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func input_for(shift: InspectionShift, tool: Dictionary) -> Dictionary:
	var facts: Array = shift.current().information.duplicate(true)
	for observation in shift.observations:
		if observation.ok and observation.get("correct_usage", true):
			facts.append_array(observation.information)
	for fact in facts:
		if Information.accepts(tool, fact):
			var token: Dictionary = fact.duplicate(true)
			token.case_id = shift.current().id
			return token
	return {}

func _initialize() -> void:
	var catalog := Fixtures.catalog()
	check(catalog.load_pack(), str(catalog.errors))
	var schema: Dictionary = ContentSchema.read_schema(ContentSchema.PROBLEM)
	var raw := Fixtures.raw("FIX-HASH")
	var external: Dictionary = raw.external_references[0]
	external.output_information = [{"id": "domain", "label": "Domain", "value": "analysis.example", "data_type": "domain"}]
	var followup := external.duplicate(true)
	followup.merge({"id": "domain_report", "accepted_information_types": ["domain"],
		"input_bindings": [{"source": external.id, "id": "domain"}], "submission_type": "domain",
		"submission_value": "analysis.example", "output_information": []}, true)
	raw.external_references.append(followup)
	raw.required_evidence = [followup.id]
	var item := raw.duplicate(true)
	check(ProblemData.normalize(item, catalog, schema).is_empty(), "許可された外部照会を辿って証拠に到達")
	var denied := raw.duplicate(true)
	denied.external_references[0].correct_usage = false
	check(not ProblemData.normalize(denied, catalog, schema).is_empty(), "不適切な照会からの後続入力を拒否")
	denied = raw.duplicate(true)
	denied.external_references[0].environments = ["windows"]
	check(not ProblemData.normalize(denied, catalog, schema).is_empty(), "非対応OSの外部照会からの後続入力を拒否")
	var alternatives := raw.duplicate(true)
	alternatives.required_evidence = ["report"]
	alternatives.evidence_alternatives = {"report": {"label": "Report", "any_of": [external.id, followup.id]}}
	check(ProblemData.normalize(alternatives, catalog, schema).is_empty(), "外部照会だけの代替証拠も許可")
	alternatives = raw.duplicate(true)
	alternatives.external_references[0].correct_usage = false
	alternatives.external_references.pop_back()
	alternatives.required_evidence = [external.id]
	check(not ProblemData.normalize(alternatives, catalog, schema).is_empty(), "不適切な外部照会の必須化を拒否")
	var shift := InspectionShift.new()
	var cases: Array[Dictionary] = [item]
	shift.start(cases)
	item = shift.current()
	var hash_tool: Dictionary = item.tools.filter(func(t): return t.id == "sha256sum")[0]
	external = item.external_references[0]
	followup = item.external_references.back()
	check(shift.inspect(hash_tool, input_for(shift, hash_tool)).ok, "照会に使うHashを取得")
	check(shift.decline_external(external, input_for(shift, external)), "必要な照会でも見送り可能")
	check(shift.missing_evidence() == [followup.id], "見送りは証拠を満たさない")
	check(not shift.observations.back().reason.contains("ToolとReferenceで"), "内部資料だけで解けると案内しない")
	check(shift.inspect(external, input_for(shift, external)).ok, "適切な外部照会を実施")
	check(shift.inspect(followup, input_for(shift, followup)).ok, "取得した外部結果を後続照会へ渡す")
	check(shift.missing_evidence().is_empty(), "外部結果で必須証拠を満たす")
	# 禁止された照会も表示・記録するが、取得結果を後続入力や証拠に使わせない。
	shift.start(cases)
	check(shift.inspect(hash_tool, input_for(shift, hash_tool)).ok, "再開始後のHash取得")
	var unsafe := external.duplicate(true)
	unsafe.correct_usage = false
	unsafe.reason = "Fixture policy forbids submission."
	var result := shift.inspect(unsafe, input_for(shift, unsafe))
	check(result.ok, "不適切な送信の結果も表示する")
	var blocked_input: Dictionary = result.information.filter(func(i): return i.id == "domain")[0].duplicate(true)
	blocked_input.case_id = item.id
	check(not shift.inspect(followup, blocked_input).ok, "不適切な送信結果を後続入力に使用できない")
	check(not shift.missing_evidence().is_empty() and shift.unsafe_investigations() == 1, "証拠不足と不適切な利用を別々に記録")
	check(shift.decide(item.ground_truth) and shift.score() == 1, "未調査でも判定可能な操作は維持")
	# UIでも必須照会の見送り・実施・回答後の説明を確認。
	test_ui.call_deferred(cases)

func test_ui(cases: Array[Dictionary]) -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	desk._start_shift()
	desk.shift.start(cases)
	var item: Dictionary = desk.shift.current()
	var hash_tool: Dictionary = item.tools.filter(func(t): return t.id == "sha256sum")[0]
	var external: Dictionary = item.external_references[0]
	var followup: Dictionary = item.external_references.back()
	desk._inspect(hash_tool, input_for(desk.shift, hash_tool))
	desk._inspect(external, input_for(desk.shift, external))
	check(desk.external_preview.visible, "必須照会でも送信前確認を表示")
	desk.external_skip.pressed.emit()
	check(desk.shift.missing_evidence() == [followup.id], "UIの見送りで証拠を取得しない")
	for tool in [external, followup]:
		desk._inspect(tool, input_for(desk.shift, tool))
		check(desk.external_preview.visible, "後続照会も送信前確認を表示")
		desk.external_send.pressed.emit()
	check(desk.shift.missing_evidence().is_empty(), "UIから後続の外部証拠を取得")
	desk.shift.decide(item.ground_truth)
	check(desk.audit_body.text.contains(item.explanation), "回答後の解説")
	desk.queue_free()
	await process_frame
	print("External evidence tests: %d failures" % failures)
	quit(1 if failures else 0)
