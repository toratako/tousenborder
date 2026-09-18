extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var desk = load("res://scenes/main.tscn").instantiate()
	root.add_child(desk)
	desk._start_shift()
	var cases: Array[Dictionary] = desk.catalog.cases.filter(func(c): return c.id == "PKG-NPM-ADVANCED-001")
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
	assert(button.heading.size.x > 180 and button.hint.size.x > 180)
	assert(button.heading.get_rect().end.y <= button.hint.position.y)
	assert(button.hint.text.begins_with("未読"))
	button.pressed.emit()
	assert(desk.tool_panel.visible)
	assert(button.hint.text.begins_with("確認済み"))
	var reference: DraggableCard = desk.active_card
	var observations: Array = desk.shift.observations.duplicate(true)
	var card_count: int = desk.cards.size()
	# 別の資料を開いた後でも同じカードを手前に戻す。
	desk.tool_buttons[1].pressed.emit()
	assert(desk.active_card != reference)
	button.pressed.emit()
	assert(desk.active_card == reference and reference.get_index() == desk.card_layer.get_child_count() - 1)
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
	assert(desk.tool_buttons.all(func(b): return not b.reviewed and b.hint.text.begins_with("未読")))
	assert(desk.tool_panel.visible)
	var beginner: Array[Dictionary] = desk.catalog.select_cases("very_beginner", "file")
	desk.shift.start(beginner)
	assert(desk.tool_buttons.is_empty() and desk.tool_panel.visible)
	assert(desk.tool_rack.get_child_count() == 1)
	assert(desk.tool_rack.get_child(0).text.contains("基本情報のみ"))
	desk.queue_free()
	await process_frame
	print("調査パネルテスト: 常設表示、Reference再利用・確認状態、問題切り替えに成功")
	quit()
