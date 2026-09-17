extends SceneTree
## 実マウスイベントでスタンプを持ち運ぶ。クリックでは判定しない。
var mouse_position := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func motion(point: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - mouse_position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	mouse_position = point
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func click(point: Vector2) -> void:
	await motion(point)
	await button(point, true)
	await button(point, false)

func drag(from: Vector2, to: Vector2) -> void:
	await motion(from)
	await button(from, true)
	await motion(from + Vector2(22, 0), true)
	await motion(to, true)
	await button(to, false)
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var desk = load("res://scenes/main.tscn").instantiate()
	root.add_child(desk)
	await process_frame
	await click(desk.start_button.get_global_rect().get_center())
	var cases: Array[Dictionary] = desk.catalog.cases.filter(func(c): return c.id == "FILE-LINUX-BEGINNER-001")
	desk.shift.start(cases)
	assert(desk.playing and not desk.tool_drawer.visible)
	desk.set_process(false)
	assert(desk.rule_card.visible and desk.rule_card.position.x > 900)
	var rules_position: Vector2 = desk.rule_card.position
	await click(desk.rule_card.close_button.get_global_rect().get_center())
	assert(not desk.rule_card.visible)
	await click(desk.rules_button.get_global_rect().get_center())
	assert(desk.rule_card.visible and desk.rule_card.position == rules_position)
	assert(desk.card_layer.position.y + desk.card_layer.size.y == 800)
	assert(not desk.has_node("InputTray"))
	var card: DraggableCard = desk.target_card
	assert(not card.movable and not card.source_label.visible)
	assert(card.scroll.position.y == 58)
	assert(card.request_section.get_child(0).get_child(0).text == "申請内容")
	assert(card.basic_section.get_child(0).get_child(0).text == "基本情報")
	assert(card.tokens[0].get_parent() == card.request_section)
	for i in range(1, card.tokens.size()):
		assert(card.tokens[i].get_parent() == card.basic_section)
	var original := card.position
	var grab := card.header.global_position + Vector2(110, 22)
	await drag(grab, grab + Vector2(100, 15))
	assert(card.position == original, "target stays fixed")
	assert(card.position == original)
	# グリップ上からも移動でき、離した後は持ち上げ表現が残らない。
	var rule_grab: Vector2 = desk.rule_card.header.global_position + Vector2(15, 23)
	var resting_shadow: int = desk.rule_card.get_theme_stylebox("panel").shadow_size
	await motion(rule_grab)
	await button(rule_grab, true)
	await motion(rule_grab + Vector2(-80, 24), true)
	assert(desk.rule_card.dragging)
	assert(desk.rule_card.get_theme_stylebox("panel").shadow_size > resting_shadow)
	await button(rule_grab + Vector2(-80, 24), false)
	await process_frame
	assert(not desk.rule_card.dragging)
	assert(desk.rule_card.get_theme_stylebox("panel").shadow_size == resting_shadow)
	assert(desk.rule_card.position.x < 900)
	desk.rule_card.position = desk.rule_card.home_position
	await click(desk.tools_toggle.get_global_rect().get_center())
	assert(desk.tool_drawer.visible)
	var row: InformationToken = card.tokens[1]
	await process_frame
	# グリップからも本文からも同じ情報を持ち出せる。
	var grip_point := row.global_position + Vector2(15, row.size.y / 2)
	await motion(grip_point)
	await button(grip_point, true)
	await motion(grip_point + Vector2(30, 0), true)
	assert(root.gui_is_dragging())
	assert(root.gui_get_drag_data().information == row.payload())
	await motion(Vector2(850, 760), true)
	await button(Vector2(850, 760), false)
	assert(desk.shift.observations.is_empty())
	await drag(row.get_global_rect().get_center(), desk.tool_buttons[0].get_global_rect().get_center())
	assert(desk.shift.observations.size() == 1 and desk.shift.observations[0].ok)
	assert(not desk.tool_drawer.visible)
	assert(desk.cards.back().card_data.category == "analysis")
	var reference: Dictionary = desk.catalog.tools_for(desk.shift.current()).filter(func(t): return t.resource_kind == "references")[0]
	desk._inspect(reference)
	var stamp: StampTool = desk.get_stamp("block")
	assert(stamp.get_class() == "Control")
	var stamp_point := stamp.get_global_rect().get_center()
	await click(stamp_point)
	assert(not desk.shift.judged, "click does not judge")
	await drag(stamp_point, desk.rule_card.header.global_position + Vector2(100, 20))
	assert(not desk.shift.judged, "rulebook rejects stamp")
	await drag(stamp_point, Vector2(860, 770))
	assert(not desk.shift.judged, "desk rejects stamp")
	var result_card: DraggableCard = desk.cards.back()
	await drag(stamp_point, result_card.header.global_position + Vector2(100, 20))
	assert(not desk.shift.judged, "analysis rejects stamp")
	# 情報行の上に落としてもカード全体が押印先になる。
	await drag(stamp_point, card.tokens[1].get_global_rect().get_center())
	assert(desk.shift.judged and card.imprint)
	assert(desk.shift.records.size() == 1 and desk.shift.records[0].correct)
	await create_timer(0.55).timeout
	assert(desk.audit_overlay.visible)
	await click(desk.next.get_global_rect().get_center())
	assert(desk.shift.finished() and desk.summary_overlay.visible)
	desk.summary_restart.pressed.emit()
	await process_frame
	assert(not desk.tool_drawer.visible and desk.rule_card.visible)
	var stale: Dictionary = desk.get_stamp("allow").payload()
	desk._start_shift()
	assert(not desk.target_card._can_drop_data(Vector2.ZERO, stale))
	desk._toggle_menu()
	assert(not desk.target_card._can_drop_data(Vector2.ZERO, desk.get_stamp("allow").payload()))
	desk.queue_free()
	await process_frame
	print("実操作テスト: ツール開閉・情報D&D・スタンプ移動・誤ドロップ拒否・押印・規則集移動に成功")
	quit()
