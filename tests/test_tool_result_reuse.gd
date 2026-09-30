extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	check(not desk.start_screen.import_button.is_visible_in_tree(), "教材追加ボタンはユーザーに表示しない")
	desk._start_shift()
	var raw := Fixtures.raw("FIX-FILE")
	var second: Dictionary = raw.initial.information[0].duplicate(true)
	second.id = "second_file"
	second.value = "second.pdf"
	raw.initial.information.append(second)
	Fixtures.resource(raw, "file").input_bindings.append(
		{ "source": "initial_information", "id": "second_file" }
	)
	Fixtures.resource(raw, "file").result.content = "調査対象: {{input}}"
	var items: Array[Dictionary] = [Fixtures.loaded(raw)]
	desk.shift.start(items)
	var tool: Button = desk.workspace.tool_buttons[0]
	var input: Dictionary = desk.workspace.target_card.tokens[1].payload()
	desk.workspace._select_information(input)
	for i in 5:
		tool.pressed.emit()
	check(desk.shift.observations.size() == 1, "連打しても調査の記録を増やさない")
	check(desk.workspace.cards.size() == 2, "対象と結果の2枚だけを生成")
	var result: DraggableCard = desk.workspace.cards.back()
	result.close_button.pressed.emit()
	check(not result.visible, "結果を閉じる")
	tool.information_dropped.emit(tool.tool, input.duplicate(true))
	check(result.visible and desk.workspace.active_card == result, "同じ情報の再ドロップで既存結果を再表示")
	check(desk.workspace.cards.size() == 2 and desk.shift.observations.size() == 1, "再表示でも増殖しない")
	var other_input: Dictionary = desk.workspace.target_card.tokens.back().payload()
	desk.workspace._inspect(tool.tool, other_input)
	check(desk.shift.observations.size() == 2 and desk.shift.observations.back().ok, "別入力は新しく調べる")
	check(desk.shift.observations.back().output.contains("second.pdf"), "別入力に対応した結果を取得")
	check(desk.workspace.cards.size() == 3, "異なる入力の結果を保持")
	tool.pressed.emit()
	check(desk.workspace.active_card == result and desk.shift.observations.size() == 2, "元の入力の結果を手前に戻す")
	desk.workspace._select_information({ })
	tool.pressed.emit()
	check(desk.shift.observations.size() == 2, "入力未選択では結果を流用しない")
	var reference: Button = desk.workspace.tool_buttons.back()
	for i in 3:
		reference.pressed.emit()
	check(desk.shift.observations.size() == 3 and desk.workspace.cards.size() == 4, "Referenceの再利用も維持")
	desk.pause_menu.restart_requested.emit()
	check(desk.workspace.tool_result_cards.is_empty(), "再開始時に以前の結果を破棄")
	desk.workspace._inspect(desk.workspace.tool_buttons[0].tool, desk.workspace.target_card.tokens[1].payload())
	check(desk.shift.observations.size() == 1 and desk.workspace.cards.size() == 2, "再開始後も新しく調査できる")
	desk.queue_free()
	await process_frame
	print("Tool result reuse tests: %d failures" % failures)
	quit(1 if failures else 0)
