extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
## 未調査・一部調査でも押印でき、判定時の証拠不足と調査履歴を保持する。

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	for reviewed in [0, 1]:
		desk._start_shift()
		var cases: Array[Dictionary] = desk.library.cases.filter(func(c): return c.id == "FIX-REFERENCES")
		desk.shift.start(cases)
		if reviewed == 1:
			desk.tool_buttons[0].pressed.emit()
		var missing: Array = desk.shift.missing_evidence().duplicate()
		assert(not missing.is_empty())
		assert(missing.size() == cases[0].required_evidence.size() - reviewed)
		for action in ["allow", "block"]:
			var stamp: StampTool = desk.get_stamp(action)
			assert(not stamp.disabled and desk._can_stamp(stamp.payload()))
		var payload: Dictionary = desk.get_stamp(cases[0].ground_truth).payload()
		assert(desk.target_card._can_drop_data(Vector2.ZERO, payload))
		desk.target_card._drop_data(Vector2.ZERO, payload)
		assert(desk.shift.judged and desk.shift.score() == 1)
		assert(not desk.shift.decide("block"))
		assert(desk.shift.records[0].missing_evidence == missing)
		assert(desk.shift.records[0].observations.size() == reviewed)
		await create_timer(0.55).timeout
		assert(desk.audit_overlay.visible)
		desk.next.pressed.emit()
		assert(desk.shift.finished() and desk.summary_overlay.visible)
		assert(desk.shift.records[0].missing_evidence == missing)
		assert(desk.shift.records[0].observations.size() == reviewed)
	desk.queue_free()
	await process_frame
	print("任意調査テスト: 未調査・一部調査での押印、進行、履歴保持に成功")
	quit()
