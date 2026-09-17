extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _settle() -> void:
	for i in range(12):
		await process_frame

func _run() -> void:
	var desk = load("res://scenes/main.tscn").instantiate()
	root.add_child(desk)
	desk._start_shift()
	var cases: Array[Dictionary] = desk.catalog.cases.filter(func(c): return c.id == "FILE-LINUX-BEGINNER-001")
	desk.shift.start(cases)
	desk._toggle_tools()
	# メッセージなしの高さを基準に、説明文による伸縮を比較する。
	desk.tool_message.text = ""
	await _settle()
	var initial_height: float = desk.tool_drawer.size.y
	assert(initial_height < 536)
	for button in desk.tool_buttons:
		button.hide()
	desk.tool_buttons[0].show()
	await _settle()
	assert(desk.tool_drawer.size.y < initial_height)
	assert(desk.tool_scroll.size.y >= desk.tool_rack.get_combined_minimum_size().y)
	var compact_height: float = desk.tool_drawer.size.y
	desk.tool_message.text = "Select a compatible information item. ".repeat(5)
	await _settle()
	assert(desk.tool_drawer.size.y > compact_height)
	assert(desk.tool_message.position.y + desk.tool_message.size.y <= desk.tool_drawer.size.y)
	desk.tool_message.text = ""
	await _settle()
	assert(is_equal_approx(desk.tool_drawer.size.y, compact_height))
	for button in desk.tool_buttons:
		button.show()
		button.custom_minimum_size.y = 260
	await _settle()
	assert(desk.tool_drawer.position.y + desk.tool_drawer.size.y <= desk.workspace.size.y)
	assert(desk.tool_scroll.get_v_scroll_bar().max_value > desk.tool_scroll.get_v_scroll_bar().page)
	var short_card = desk.add_information_card({"category": "analysis", "information": [{"label": "Status", "value": "OK"}]})
	var long_card = desk.add_information_card({"category": "analysis", "information": [{"label": "Result", "value": "Long wrapped output with details. ".repeat(200)}]})
	await _settle()
	assert(short_card.size.y < 300)
	assert(short_card.scroll.size.y >= short_card.rows.get_combined_minimum_size().y)
	assert(long_card.size.y > short_card.size.y)
	assert(long_card.position.y + long_card.size.y <= desk.card_layer.size.y)
	assert(long_card.scroll.get_v_scroll_bar().max_value > long_card.scroll.get_v_scroll_bar().page)
	var settled_height: float = long_card.size.y
	await _settle()
	assert(is_equal_approx(long_card.size.y, settled_height))
	assert(desk.target_card.size == Vector2(480, 672))
	print("Content sizing tests passed")
	quit()
