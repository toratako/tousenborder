extends SceneTree
## 実際のシーンとボタンのシグナルを使い、勤務全体を検証する。

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var desk = load("res://scenes/main.tscn").instantiate()
	root.add_child(desk)
	await process_frame
	assert(desk.start_screen.visible and not desk.workspace.visible)
	assert(desk.start_button.has_focus())
	desk.tool_guide_button.pressed.emit()
	assert(desk.tool_guide.visible and not desk.start_screen.visible)
	assert(desk.tool_guide_close.has_focus())
	var legacy_tool: Dictionary = desk.catalog.tools[0].duplicate(true)
	legacy_tool.erase("detailed_description")
	assert(desk._tool_description(legacy_tool).contains(legacy_tool.description))
	assert(desk.tool_guide_tabs.size() == desk.catalog.tools.size())
	assert(desk.tool_guide_tabs[0].button_pressed)
	for i in range(desk.catalog.tools.size()):
		var tool: Dictionary = desk.catalog.tools[i]
		desk.tool_guide_tabs[i].pressed.emit()
		assert(desk.tool_guide_body.get_parsed_text().contains(tool.label))
		assert(desk.tool_guide_body.get_parsed_text().contains(tool.detailed_description))
		for j in range(desk.tool_guide_tabs.size()):
			assert(desk.tool_guide_tabs[j].button_pressed == (i == j))
			if i != j:
				assert(not desk.tool_guide_body.get_parsed_text().contains(desk.catalog.tools[j].detailed_description))
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
	assert(desk.license_body.text.contains(FileAccess.get_file_as_string("res://assets/fonts/LICENSE")))
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
	assert(not desk.start_screen.visible and desk.workspace.visible)
	assert(desk.playing and desk.countdown.text == "05:00")
	assert(desk.countdown_state.text.is_empty())
	assert(desk.tool_buttons.size() == 8)
	for i in range(desk.tool_buttons.size()):
		assert(desk.tool_buttons[i].tooltip_text.contains(desk.catalog.tools[i].description))
		assert(not desk.tool_buttons[i].tooltip_text.contains(desk.catalog.tools[i].detailed_description))
	assert(not desk.audit_overlay.visible)
	var expected_icons := ["executable", "package", "web", "packet", "executable", "web"]
	for i in range(6):
		assert(desk.dossier_title.text == desk.shift.current().title)
		assert(desk.dossier_icon.texture.resource_path.ends_with(expected_icons[i] + ".svg"))
		if desk.shift.current().fields.has("サイズ"):
			assert(desk.dossier_meta.text.contains(desk.shift.current().fields["サイズ"]))
		if i == 4:
			assert(desk.dossier_meta.text.contains(".exe"))
			assert(not desk.dossier_meta.text.contains(".pdf"))
		for tool_index in range(desk.tool_buttons.size()):
			var compatible: bool = desk.shift.current().type in desk.catalog.tools[tool_index].target_types
			assert(desk.tool_buttons[tool_index].visible == compatible)
		for button in desk.tool_buttons:
			if button.visible and not button.disabled:
				button.pressed.emit()
		if desk.shift.current().type in ["file", "process"]:
			assert(not desk.dossier_meta.text.contains("サイズ未記載"))
			assert(desk.terminal.text.contains(desk.shift.current().evidence.entropy))
			assert(desk.terminal.text.contains(desk.shift.current().evidence.file))
		assert(not desk.shift.observations.is_empty())
		var evidence_text: String = desk.terminal.text
		var explanation: String = desk.shift.current().explanation
		if i == 0:
			desk.deny.pressed.emit()
		else:
			desk.approve.pressed.emit()
		assert(desk.next.visible and not desk.approve.visible)
		assert(desk.audit_overlay.visible)
		assert(desk.audit_overlay.mouse_filter == Control.MOUSE_FILTER_STOP)
		assert(desk.next.has_focus())
		assert(desk.audit_body.text.contains(explanation))
		assert(desk.terminal.text == evidence_text)
		assert(desk.audit_heading.text.contains("規則に適合" if desk.shift.records.back().correct else "誤判定"))
		if i == 5:
			assert(desk.next.text.contains("勤務を終了"))
		desk.next.pressed.emit()
		await process_frame
		assert(not desk.audit_overlay.visible)
	assert(desk.shift.finished() and is_instance_valid(desk.summary))
	assert(desk.summary_overlay.visible and desk.summary_overlay.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(desk.summary_overlay.get_parent() == desk)
	assert(desk.summary_restart.has_focus())
	assert(desk.summary_review.get_parsed_text().contains("quarterly-report.pdf.exe"))
	var previous_overlay = desk.summary_overlay
	desk._refresh()
	assert(desk.summary_overlay == previous_overlay)
	var restart: Button = desk.summary_restart
	restart.pressed.emit()
	await process_frame
	assert(desk.shift.index == 0 and desk.shift.records.is_empty())
	assert(desk.approve.visible and not desk.next.visible)
	assert(not is_instance_valid(desk.summary_overlay))
	desk.set_process(false)
	assert(desk.countdown.text.contains("05:00"))
	desk._process(271)
	assert(desk.countdown.text.contains("00:29"))
	desk._process(29)
	assert(desk.shift.timed_out and is_instance_valid(desk.summary))
	assert(desk.countdown.text.contains("00:00"))
	assert(not desk.approve.visible and not desk.audit_overlay.visible)
	assert(desk.summary_title.text.contains("時間切れ"))
	assert(desk.summary_stats.text.contains("未審査 6件"))
	assert(desk.summary_overlay.visible and desk.summary_restart.has_focus())
	var timeout_restart: Button = desk.summary_restart
	timeout_restart.pressed.emit()
	await process_frame
	assert(not desk.shift.timed_out and desk.countdown.text.contains("05:00"))
	desk._process(300)
	desk.summary_home.pressed.emit()
	await process_frame
	assert(desk.start_screen.visible and not desk.workspace.visible)
	assert(not is_instance_valid(desk.summary_overlay))
	var remaining: float = desk.shift.remaining_seconds
	desk._process(600)
	assert(desk.shift.remaining_seconds == remaining)
	desk.start_button.pressed.emit()
	assert(desk.shift.records.is_empty() and desk.countdown.text == "05:00")
	print("画面テスト: 許可・拒否の監査票、調査ログの保持、全案件の進行と再開始に成功")
	desk.queue_free()
	await process_frame
	quit()
