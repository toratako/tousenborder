extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")

func _initialize() -> void:
	_run.call_deferred()

func _settle() -> void:
	for i in range(12):
		await process_frame

func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	desk._start_shift()
	var cases: Array[Dictionary] = desk.library.cases.filter(func(c): return c.id == "FIX-FILE")
	desk.shift.start(cases)
	# パネルは固定し、案内の高さに応じて一覧のスクロール領域だけを縮める。
	desk.tool_message.text = ""
	await _settle()
	var panel_height: float = desk.tool_panel.size.y
	var scroll_height: float = desk.tool_scroll.size.y
	assert(desk.tool_panel.position.y == 72)
	assert(desk.tool_panel.get_rect().end == desk.workspace.size - Vector2(0, 16))
	assert(not desk.tool_panel.get_global_rect().intersects(desk.stamp_rack.get_global_rect()))
	assert(desk.tool_scroll.size.y >= desk.tool_rack.get_combined_minimum_size().y)
	desk.tool_message.text = "Select a compatible information item. ".repeat(20)
	await _settle()
	assert(is_equal_approx(desk.tool_panel.size.y, panel_height))
	assert(desk.tool_scroll.size.y < scroll_height and desk.tool_scroll.size.y > 0)
	assert(desk.tool_message.position.y + desk.tool_message.size.y <= panel_height)
	desk.tool_message.text = ""
	await _settle()
	assert(is_equal_approx(desk.tool_scroll.size.y, scroll_height))
	var dense_cases: Array[Dictionary] = desk.library.cases.filter(func(c): return c.id == "FIX-PRIVATE-FILE")
	desk.shift.start(dense_cases)
	for button in desk.tool_buttons:
		button.heading.text = (button.tool.label + " Extended description ").repeat(3)
	await _settle()
	assert(desk.tool_panel.get_rect().end.y <= desk.workspace.size.y)
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
	assert(desk.target_card.size == Vector2(480, 592))
	assert(desk.target_card.get_global_rect().end.y < desk.stamp_rack.global_position.y)
	assert(desk.stamp_rack.get_global_rect().end.y <= desk.workspace.size.y)
	assert(desk.stamp_rack.get_global_rect().end.x < desk.target_card.get_global_rect().end.x)
	long_card.position = Vector2(2000, 20)
	long_card.clamp_to_desk()
	assert(long_card.get_global_rect().end.x < desk.tool_panel.global_position.x)
	long_card.position = Vector2.ZERO
	long_card.clamp_to_desk()
	assert(long_card.position == Vector2.ZERO)
	print("Content sizing tests passed")
	quit()
