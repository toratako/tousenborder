extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
## 実際のシーンとボタンのシグナルを使い、勤務全体を検証する。


func _initialize() -> void:
	call_deferred("_run")


func _escape(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	assert(desk.start_screen.visible and not desk.workspace.visible)
	assert(desk.start_button.has_focus())
	await _escape()
	assert(not desk.pause_menu.visible and desk.start_screen.visible)
	desk.tool_guide_button.pressed.emit()
	assert(desk.tool_guide.visible and not desk.start_screen.visible)
	assert(desk.tool_guide_close.has_focus())
	assert(desk.tool_guide_tabs.size() == desk.guide_tools.size())
	assert(desk.tool_guide_tabs[0].button_pressed)
	for i in range(desk.guide_tools.size()):
		var tool: Dictionary = desk.guide_tools[i]
		desk.tool_guide_tabs[i].pressed.emit()
		assert(desk.tool_guide_body.get_parsed_text().contains(tool.label))
		assert(desk.tool_guide_body.get_parsed_text().contains(tool.description))
		for j in range(desk.tool_guide_tabs.size()):
			assert(desk.tool_guide_tabs[j].button_pressed == (i == j))
	desk.start_button.pressed.emit()
	desk.license_button.pressed.emit()
	desk._process(600)
	assert(not desk.playing and desk.shift.cases.is_empty())
	desk.tool_guide_close.pressed.emit()
	assert(not desk.tool_guide.visible and desk.start_screen.visible)
	assert(desk.tool_guide_button.has_focus())
	desk.tool_guide_button.pressed.emit()
	assert(desk.tool_guide.visible)
	assert(desk.tool_guide_tabs.back().button_pressed)
	desk.tool_guide_close.pressed.emit()
	desk.license_button.pressed.emit()
	assert(desk.license_overlay.visible and desk.license_close.has_focus())
	assert(desk.start_button.disabled)
	assert(desk.tool_guide_button.disabled)
	desk.tool_guide_button.pressed.emit()
	assert(not desk.tool_guide.visible)
	assert(desk.license_body.text.contains(Engine.get_license_text()))
	desk.start_button.pressed.emit()
	assert(not desk.playing)
	desk.license_tabs[1].pressed.emit()
	assert(desk.license_body.text.contains("2014-2021 Adobe"))
	assert(
		desk.license_body.text.contains(FileAccess.get_file_as_string("res://assets/fonts/LICENSE"))
	)
	desk.license_tabs[2].pressed.emit()
	assert(desk.license_body.text.contains(Engine.get_copyright_info()[0].name))
	desk.license_tabs[3].pressed.emit()
	for text in Engine.get_license_info().values():
		assert(desk.license_body.text.contains(text))
	desk._process(600)
	assert(not desk.playing and desk.shift.cases.is_empty())
	desk.license_close.pressed.emit()
	assert(not desk.license_overlay.visible and desk.license_button.has_focus())
	assert(not desk.start_button.disabled)
	desk._process(600)
	assert(desk.shift.cases.is_empty() and not desk.playing)
	desk.start_button.pressed.emit()
	assert(desk.elapsed_time.text == "00:00")
	assert(desk.status.text == "問題: 1/%d" % Fixtures.count())
	assert(not desk.target_card.scroll_hint.visible and not desk.target_card.stamp_plate.visible)
	desk._show_start_screen()
	for i in desk.method_select.item_count:
		if desk.method_select.get_item_metadata(i) == "initial":
			desk.method_select.select(i)
	desk.start_button.pressed.emit()
	assert(not desk.start_screen.visible and desk.workspace.visible)
	assert(desk.playing and desk.elapsed_time.text == "00:00")
	assert(desk.tool_buttons.is_empty())
	assert(not desk.audit_overlay.visible)
	desk.set_process(false)
	assert(not desk.rules_overlay.visible)
	desk.rules_button.grab_focus()
	desk.rules_button.pressed.emit()
	assert(desk.rules_overlay.visible and desk.rules_close.has_focus())
	assert(desk.rules_overlay.mouse_filter == Control.MOUSE_FILTER_STOP)
	for rule in desk.rules:
		assert(desk.rules_body.get_parsed_text().contains(rule.label))
		assert(desk.rules_body.get_parsed_text().contains(Information.display(rule.value)))
	var book_time: float = desk.shift.elapsed_seconds
	desk._process(600)
	assert(desk.shift.elapsed_seconds == book_time)
	for i in range(6):
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		Input.parse_input_event(tab)
		await process_frame
		assert(root.gui_get_focus_owner() in [desk.rules_close, desk.rules_body])
	await _escape(true)
	assert(desk.rules_overlay.visible)
	await _escape()
	assert(not desk.rules_overlay.visible and not desk.pause_menu.visible)
	assert(desk.rules_button.has_focus())
	desk.rules_button.pressed.emit()
	desk._show_start_screen()
	assert(not desk.rules_overlay.visible)
	desk.start_button.pressed.emit()
	assert(not desk.rules_overlay.visible)
	desk._process(12)
	var paused_time: float = desk.shift.elapsed_seconds
	var paused_log: Array = desk.shift.observations.duplicate(true)
	await _escape()
	assert(desk.pause_menu.visible and desk.menu_resume.has_focus())
	assert(desk.workspace.visible)
	# Tabを繰り返しても、背面の判定・調査ボタンへ移動しない。
	for i in range(6):
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		Input.parse_input_event(tab)
		await process_frame
		assert(root.gui_get_focus_owner() in [desk.menu_resume, desk.menu_restart, desk.menu_home])
	desk._process(600)
	assert(desk.shift.elapsed_seconds == paused_time)
	await _escape(true)
	assert(desk.pause_menu.visible)
	await _escape()
	assert(not desk.pause_menu.visible and desk.workspace.visible)
	assert(desk.menu_button.has_focus() and desk.shift.observations == paused_log)
	desk._process(1)
	assert(desk.shift.elapsed_seconds == paused_time + 1)
	desk._toggle_menu()
	assert(desk.pause_menu.visible)
	desk.menu_resume.pressed.emit()
	assert(not desk.pause_menu.visible and desk.shift.observations == paused_log)
	desk._toggle_menu()
	desk.menu_restart.pressed.emit()
	assert(not desk.pause_menu.visible and desk.workspace.visible)
	assert(desk.shift.index == 0 and desk.shift.observations.is_empty())
	assert(desk.elapsed_time.text == "00:00")
	desk._toggle_menu()
	desk.menu_home.pressed.emit()
	assert(not desk.pause_menu.visible and desk.start_screen.visible and not desk.playing)
	assert(not desk.workspace.visible and desk.start_button.has_focus())
	desk.start_button.pressed.emit()
	for i in range(2):
		assert(desk.status.text == "問題: %d/2" % (i + 1))
		assert(desk.target_card.title_label.text == "検査対象")
		assert(desk.target_card.tokens.size() == desk.shift.current().information.size() + 1)
		assert(not desk.target_card.card_data.has("ground_truth"))
		var evidence: Array = desk.shift.observations.duplicate(true)
		var explanation: String = desk.shift.current().explanation
		var stamp: StampTool = desk.get_stamp(desk.shift.current().ground_truth)
		assert(not desk.shift.judged)
		desk.target_card._drop_data(Vector2.ZERO, stamp.payload())
		assert(desk.shift.judged and desk.stamp_pending)
		assert(desk.target_card.stamp_plate.visible and desk.target_card.imprint)
		await create_timer(0.5).timeout
		assert(desk.next.visible and not desk.get_stamp("allow").visible)
		assert(desk.audit_overlay.visible)
		assert(desk.audit_overlay.mouse_filter == Control.MOUSE_FILTER_STOP)
		assert(desk.next.has_focus())
		if i == 0:
			var audit_text: String = desk.audit_body.text
			await _escape()
			assert(desk.pause_menu.visible and desk.audit_overlay.visible)
			await _escape()
			assert(desk.audit_overlay.visible and desk.next.has_focus())
			assert(desk.audit_body.text == audit_text and desk.shift.records.size() == 1)
		assert(desk.audit_body.text.contains(explanation))
		assert(desk.shift.observations == evidence)
		desk.next.pressed.emit()
		await process_frame
		assert(not desk.audit_overlay.visible)
	assert(desk.shift.finished() and is_instance_valid(desk.summary))
	assert(
		desk.summary_overlay.visible
		and desk.summary_overlay.mouse_filter == Control.MOUSE_FILTER_STOP
	)
	assert(desk.summary_overlay.get_parent() == desk)
	assert(desk.summary_restart.has_focus())
	await _escape()
	assert(desk.pause_menu.visible and desk.summary_overlay.visible)
	await _escape()
	assert(desk.summary_overlay.visible and desk.summary_restart.has_focus())
	assert(desk.summary_review.get_parsed_text().contains(desk.shift.cases[0].title))
	assert(desk.summary_restart.text == "同じ問題に再挑戦")
	var first_session: String = desk.completed_snapshot.session_id
	var previous_overlay = desk.summary_overlay
	desk._refresh()
	assert(desk.summary_overlay == previous_overlay)
	var restart: Button = desk.summary_restart
	restart.pressed.emit()
	await process_frame
	assert(desk.shift.index == 0 and desk.shift.records.is_empty())
	assert(desk.get_stamp("allow").visible and not desk.next.visible)
	assert(not is_instance_valid(desk.summary_overlay))
	desk.set_process(false)
	assert(desk.elapsed_time.text.contains("00:00"))
	desk._process(0.75)
	assert(desk.elapsed_time.text == "00:00")
	desk._process(0.25)
	assert(desk.elapsed_time.text == "00:01")
	desk._process(299)
	assert(desk.elapsed_time.text == "05:00" and not desk.shift.finished())
	assert(not is_instance_valid(desk.summary_overlay) and desk.get_stamp("allow").visible)
	desk._process(5700)
	assert(desk.elapsed_time.text == "100:00")
	for i in range(2):
		assert(desk.shift.decide(desk.shift.current().ground_truth))
		desk._process(60)
		assert(desk.elapsed_time.text == "100:00")
		desk.next.pressed.emit()
	assert(desk.shift.finished())
	desk._process(600)
	assert(desk.elapsed_time.text == "100:00")
	assert(
		desk.summary_title.text == "再挑戦の結果" and desk.completed_snapshot.retry_of == first_session
	)
	desk.summary_home.pressed.emit()
	await process_frame
	assert(desk.start_screen.visible and not desk.workspace.visible)
	assert(not is_instance_valid(desk.summary_overlay))
	var elapsed: float = desk.shift.elapsed_seconds
	desk._process(600)
	assert(desk.shift.elapsed_seconds == elapsed)
	desk.start_button.pressed.emit()
	assert(desk.shift.records.is_empty() and desk.elapsed_time.text == "00:00")
	print("画面テスト: メニューの開閉・時間停止・画面復帰、監査票、調査ログの保持、全案件の進行と再開始に成功")
	desk.queue_free()
	await process_frame
	quit()
