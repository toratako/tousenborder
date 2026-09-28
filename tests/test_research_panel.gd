extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	desk._start_shift()
	var cases: Array[Dictionary] = desk.library.cases.filter(
		func(c):
			return c.id == "FIX-REFERENCES",
	)
	var approved := {
		"製品": "帳票Tool",
		"Path": "C:\\Company\\report.exe",
		"承認条件": { "Version": "2.3", "署名": "未署名の社内版" },
		"接続先": ["192.0.2.80:443", "192.0.2.81:443"],
		"追加依存": { },
		"例外": [],
	}
	var literal_json := "package.json抜粋:\n{\"dependencies\": {\"core\": \"2.5.0\"}}"
	Fixtures.resources(cases[0], "references")[0].result.content = approved.duplicate(true)
	Fixtures.resources(cases[0], "references")[1].result.content = literal_json
	desk.shift.start(cases)
	await process_frame
	assert(desk.tool_panel.is_visible_in_tree())
	assert(desk.tool_buttons.size() == 4)
	var headings: Array[String] = []
	for child in desk.tool_rack.get_children():
		if child is Label:
			headings.append(child.text)
	assert(headings == ["Reference"], "空のTool・外部照会の見出しは出さない")
	var button: ToolInput = desk.tool_buttons[0]
	assert(button.heading.size.x > 150)
	assert(is_instance_valid(button.reference_icon) and not button.hint.visible)
	assert(button.reference_icon.get_rect().end.x < button.heading.position.x)
	assert(button.get_theme_stylebox("normal").bg_color.a == 0)
	assert(button.hint.text.begins_with("未読"))
	button.pressed.emit()
	assert(desk.tool_panel.visible)
	assert(button.hint.text.begins_with("確認済み"))
	var reference: DraggableCard = desk.active_card
	var value_label: Label = reference.tokens[0].get_child(0).get_child(1)
	assert(
		value_label.text
		== "製品: 帳票Tool\nPath: C:\\Company\\report.exe\n承認条件:\n  Version: 2.3\n  署名: 未署名の社内版\n接続先:\n  • 192.0.2.80:443\n  • 192.0.2.81:443\n追加依存: なし\n例外: なし",
		"資料はJSONの括弧・引用符・Pathのエスケープを付けずに表示",
	)
	assert(reference.tokens[0].payload().value == approved, "表示の整形で元の情報値・型を変更しない")
	assert(desk.shift.observations.back().output == "照合用情報: " + value_label.text, "調査記録もカードと同じ項目表示")
	var observations: Array = desk.shift.observations.duplicate(true)
	var card_count: int = desk.cards.size()
	# 別の資料を開いた後でも同じカードを手前に戻す。
	desk.tool_buttons[1].pressed.emit()
	assert(desk.active_card != reference)
	var literal_label: Label = desk.active_card.tokens[0].get_child(0).get_child(1)
	assert(literal_label.text == literal_json, "JSONそのものの抜粋は括弧を含めて保持")
	button.pressed.emit()
	assert(
		desk.active_card == reference
		and reference.get_index() == desk.card_layer.get_child_count() - 1
	)
	assert(desk.shift.observations.size() == observations.size() + 1)
	assert(desk.cards.size() == card_count + 1)
	reference.close_button.pressed.emit()
	assert(not reference.visible)
	button.pressed.emit()
	assert(reference.visible and desk.active_card == reference)
	assert(desk.shift.observations.size() == observations.size() + 1)
	# メニュー中の資料再表示も背面操作として止める。
	reference.hide()
	desk._toggle_menu()
	button.pressed.emit()
	assert(not reference.visible)
	desk._close_menu()
	# 問題を切り替えると資料と確認済み状態を作り直す。
	desk._clear_desk()
	desk.shift.start(cases)
	assert(desk.reference_cards.is_empty())
	assert(
		desk.tool_buttons.all(
			func(b):
				return not b.reviewed and b.hint.text.begins_with("未読"),
		)
	)
	assert(desk.tool_panel.visible)
	var beginner: Array[Dictionary] = desk.library.select_cases("", "file", "", "initial")
	desk.shift.start(beginner)
	assert(desk.tool_buttons.is_empty() and desk.tool_panel.visible)
	assert(desk.tool_rack.get_child_count() == 1)
	assert(desk.tool_rack.get_child(0).text.contains("基本情報のみ"))
	desk.queue_free()
	await process_frame
	print("調査パネルテスト: 常設表示、Reference再利用・確認状態、問題切り替えに成功")
	quit()
