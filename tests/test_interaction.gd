extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
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
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	await click(desk.start_screen.start_button.get_global_rect().get_center())
	var cases: Array[Dictionary] = desk.library.cases.filter(
		func(c):
			return c.id == "FIX-FILE",
	)
	desk.shift.start(cases)
	assert(desk.workspace.playing and desk.workspace.tool_panel.visible)
	await motion(desk.workspace.menu_button.get_global_rect().get_center())
	assert(root.gui_get_hovered_control() == desk.workspace.menu_button)
	assert(desk.workspace.menu_button.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	await click(desk.workspace.menu_button.get_global_rect().get_center())
	assert(desk.pause_menu.visible and desk.pause_menu.resume_button.has_focus())
	var paused_time: float = desk.shift.elapsed_seconds
	desk._process(600)
	assert(desk.shift.elapsed_seconds == paused_time)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	assert(not desk.pause_menu.visible and desk.workspace.menu_button.has_focus())
	assert(not desk.rules_overlay.visible)
	await click(desk.workspace.rules_button.get_global_rect().get_center())
	assert(desk.rules_overlay.visible)
	await click(desk.workspace.menu_button.get_global_rect().get_center())
	assert(not desk.pause_menu.visible, "book blocks background menu button")
	await click(desk.workspace.tool_buttons[0].get_global_rect().get_center())
	assert(desk.shift.observations.is_empty(), "book blocks background input")
	await click(desk.rules_overlay.close_button.get_global_rect().get_center())
	assert(not desk.rules_overlay.visible and desk.workspace.rules_button.has_focus())
	assert(desk.workspace.card_layer.position.y + desk.workspace.card_layer.size.y == 800)
	assert(not desk.has_node("InputTray"))
	var card: DraggableCard = desk.workspace.target_card
	await motion(desk.workspace.get_stamp("block").get_global_rect().get_center())
	assert(not desk.workspace.get_stamp("block").disabled and card.hover_drop_available)
	assert(not card.movable and not card.source_label.visible)
	assert(card.scroll.position.y == 58)
	assert(card.request_section.get_child(0).get_child(0).text == "申請内容")
	assert(card.basic_section.get_child(0).get_child(0).text == "基本情報")
	assert(card.basic_section.get_child_count() == card.tokens.size())
	assert(card.tokens[0].get_parent() == card.request_section)
	for i in range(1, card.tokens.size()):
		assert(card.tokens[i].get_parent() == card.basic_section)
	var original := card.position
	var grab := card.header.global_position + Vector2(110, 22)
	await drag(grab, grab + Vector2(100, 15))
	assert(card.position == original, "target stays fixed")
	assert(card.position == original)
	assert(desk.workspace.tool_panel.visible)
	var row: InformationToken = card.tokens[1]
	await process_frame
	# ホバーだけで対応する入力先が分かり、選択や調査は発生しない。
	await motion(card.tokens[0].get_global_rect().get_center())
	assert(
		desk.workspace.tool_buttons.all(
			func(tool):
				return not tool.hover_drop_ready,
		)
	)
	await motion(row.get_global_rect().get_center())
	assert(desk.workspace.tool_buttons[0].hover_drop_ready)
	for tool in desk.workspace.tool_buttons:
		assert(
			tool.hover_drop_ready
			== tool._can_drop_data(
				Vector2.ZERO,
				{ "kind": "information", "information": row.payload() },
			)
		)
	assert(desk.workspace.selected_information.is_empty() and desk.shift.observations.is_empty())
	await motion(Vector2(850, 760))
	assert(
		desk.workspace.tool_buttons.all(
			func(tool):
				return not tool.hover_drop_ready,
		)
	)
	# グリップからも本文からも同じ情報を持ち出せる。
	var grip_point := row.global_position + Vector2(15, row.size.y / 2)
	await motion(grip_point)
	await button(grip_point, true)
	await motion(grip_point + Vector2(30, 0), true)
	assert(root.gui_is_dragging())
	assert(
		desk.workspace.tool_buttons[0].drop_ready
		and not desk.workspace.tool_buttons[0].hover_drop_ready
	)
	assert(root.gui_get_drag_data().information == row.payload())
	await motion(Vector2(850, 760), true)
	await button(Vector2(850, 760), false)
	assert(desk.shift.observations.is_empty())
	await drag(
		row.get_global_rect().get_center(),
		desk.workspace.tool_buttons[0].get_global_rect().get_center(),
	)
	assert(desk.shift.observations.size() == 1 and desk.shift.observations[0].ok)
	assert(desk.workspace.tool_panel.visible)
	assert(desk.workspace.cards.back().card_data.category == "analysis")
	# 調査結果はグリップで移動でき、離すと持ち上げ表現が戻る。
	var movable_card: DraggableCard = desk.workspace.cards.back()
	var result_grab: Vector2 = movable_card.header.global_position + Vector2(15, 23)
	var resting_shadow: int = movable_card.get_theme_stylebox("panel").shadow_size
	await motion(result_grab)
	await button(result_grab, true)
	await motion(result_grab + Vector2(80, 24), true)
	assert(movable_card.dragging)
	assert(movable_card.get_theme_stylebox("panel").shadow_size > resting_shadow)
	await button(result_grab + Vector2(80, 24), false)
	assert(not movable_card.dragging)
	assert(movable_card.get_theme_stylebox("panel").shadow_size == resting_shadow)
	assert(movable_card.position != movable_card.home_position)
	# 結果を検査対象の上に重ねても、対象の操作で前後関係は変わらない。
	var result_position := movable_card.position
	var overlap_position := Vector2(100, 300)
	result_grab = movable_card.header.global_position + Vector2(15, 23)
	await drag(
		result_grab,
		desk.workspace.card_layer.global_position + overlap_position + Vector2(15, 23),
	)
	assert(movable_card.position.is_equal_approx(overlap_position))
	assert(movable_card.get_global_rect().intersects(card.get_global_rect()))
	await click(card.header.global_position + Vector2(110, 22))
	assert(card.get_index() == 0 and card.position == original and not card.dragging)
	await click(row.get_global_rect().get_center())
	assert(desk.workspace.active_card == card and card.get_index() == 0)
	await motion(movable_card.header.global_position + Vector2(15, 23))
	assert(root.gui_get_hovered_control() == movable_card.header)
	result_grab = movable_card.header.global_position + Vector2(15, 23)
	await drag(
		result_grab,
		desk.workspace.card_layer.global_position + result_position + Vector2(15, 23),
	)
	var reference: Dictionary = desk.library.tools_for(desk.shift.current()).filter(
		func(t):
			return t.kind == "references",
	)[0]
	desk.workspace._inspect(reference)
	var stamp: StampTool = desk.workspace.get_stamp("block")
	assert(stamp.get_class() == "Control")
	var stamp_point := stamp.get_global_rect().get_center()
	await motion(stamp_point)
	assert(card.hover_drop_available and not card.drop_available)
	assert(not desk.shift.judged)
	desk._toggle_menu()
	await process_frame
	assert(not card.hover_drop_available)
	desk._close_menu()
	await motion(Vector2(850, 760))
	assert(not card.hover_drop_available)
	await click(stamp_point)
	assert(not desk.shift.judged, "click does not judge")
	desk.workspace.rules_button.pressed.emit()
	assert(not desk.workspace._can_stamp(stamp.payload()), "book blocks stamping")
	await drag(stamp_point, card.tokens[1].get_global_rect().get_center())
	assert(not desk.shift.judged, "book blocks background stamp drag")
	desk.rules_overlay.close_button.pressed.emit()
	await drag(stamp_point, Vector2(860, 770))
	assert(not desk.shift.judged, "desk rejects stamp")
	var result_card: DraggableCard = desk.workspace.cards.back()
	await drag(stamp_point, result_card.header.global_position + Vector2(100, 20))
	assert(not desk.shift.judged, "analysis rejects stamp")
	# 情報行の上に落としてもカード全体が押印先になる。
	await drag(stamp_point, card.tokens[1].get_global_rect().get_center())
	assert(desk.shift.judged and card.imprint)
	assert(desk.shift.records.size() == 1 and desk.shift.records[0].correct)
	await create_timer(0.55).timeout
	assert(desk.audit_overlay.visible)
	await click(desk.audit_overlay.next_button.get_global_rect().get_center())
	assert(desk.shift.finished() and desk.summary_screen.visible)
	desk.summary_screen.restart.pressed.emit()
	await process_frame
	assert(desk.workspace.tool_panel.visible and not desk.rules_overlay.visible)
	var stale: Dictionary = desk.workspace.get_stamp("allow").payload()
	desk._start_shift()
	assert(not desk.workspace.target_card._can_drop_data(Vector2.ZERO, stale))
	desk._toggle_menu()
	assert(
		not desk
		.workspace
		.target_card
		._can_drop_data(Vector2.ZERO, desk.workspace.get_stamp("allow").payload())
	)
	desk.queue_free()
	await process_frame
	print("実操作テスト: 調査パネル・情報D&D・スタンプ移動・誤ドロップ拒否・押印・規則集の開閉に成功")
	quit()
