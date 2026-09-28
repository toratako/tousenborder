extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")


## ギャラリーの入力隔離・ページ境界・勤務状態の保持を検証する。
func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	desk.set_process(false)
	assert(desk.how_to_overlay.HOW_TO_SLIDES.size() <= 10)
	for path in desk.how_to_overlay.HOW_TO_SLIDES:
		var texture = load(path)
		assert(texture is Texture2D and texture.get_size() == Vector2(1440, 750))
	desk._open_how_to()
	assert(not desk.how_to_overlay.visible)
	desk._start_shift()
	var cases: Array[Dictionary] = desk.library.cases.filter(
		func(c):
			return c.id == "FIX-FILE",
	)
	desk.shift.start(cases)
	await process_frame
	var token: InformationToken = desk.workspace.target_card.tokens.filter(
		func(t):
			return t.information.id == "File名",
	)[0]
	token.selected.emit(token.payload())
	var button: Button = desk.workspace.tool_buttons.filter(
		func(b):
			return b.tool.id == "file",
	)[0]
	button.pressed.emit()
	var selected: Dictionary = desk.workspace.selected_information.duplicate(true)
	var observations: Array = desk.shift.observations.duplicate(true)
	var card_position: Vector2 = desk.workspace.cards.back().position
	desk._process(12)
	var elapsed: float = desk.shift.elapsed_seconds
	desk.workspace.how_to_button.grab_focus()
	desk.workspace.how_to_button.pressed.emit()
	assert(desk.how_to_overlay.visible and desk.how_to_overlay.close_button.has_focus())
	assert(
		desk.how_to_overlay.counter.text == "1 / 6" and desk.how_to_overlay.previous_button.disabled
	)
	desk._process(600)
	assert(desk.shift.elapsed_seconds == elapsed)
	button.pressed.emit()
	desk.workspace.target_card._drop_data(Vector2.ZERO, desk.workspace.get_stamp("allow").payload())
	desk.workspace.rules_button.pressed.emit()
	desk._toggle_menu()
	assert(desk.shift.observations == observations and not desk.shift.judged)
	assert(not desk.rules_overlay.visible and not desk.pause_menu.visible)
	await _key(KEY_LEFT)
	assert(desk.how_to_overlay.index == 0)
	desk.how_to_overlay.next_button.pressed.emit()
	assert(desk.how_to_overlay.index == 1 and not desk.how_to_overlay.previous_button.disabled)
	await _key(KEY_LEFT)
	assert(desk.how_to_overlay.index == 0)
	for i in range(5):
		desk.how_to_overlay.next_button.grab_focus()
		await _key(KEY_RIGHT)
		assert(desk.how_to_overlay.index == i + 1)
		assert(
			desk.how_to_overlay.image.texture.resource_path
			== desk.how_to_overlay.HOW_TO_SLIDES[i + 1]
		)
	assert(desk.how_to_overlay.next_button.disabled and desk.how_to_overlay.counter.text == "6 / 6")
	assert(desk.how_to_overlay.close_button.has_focus())
	await _key(KEY_RIGHT)
	assert(desk.how_to_overlay.index == 5)
	for i in range(6):
		await _key(KEY_TAB)
		assert(
			root.gui_get_focus_owner()
			in [desk.how_to_overlay.previous_button, desk.how_to_overlay.close_button]
		)
	await _key(KEY_ESCAPE, true)
	assert(desk.how_to_overlay.visible)
	await _key(KEY_ESCAPE)
	assert(not desk.how_to_overlay.visible and not desk.pause_menu.visible)
	assert(desk.workspace.how_to_button.has_focus())
	assert(
		desk.workspace.selected_information == selected and desk.shift.observations == observations
	)
	assert(desk.workspace.cards.back().position == card_position)
	desk._process(1)
	assert(desk.shift.elapsed_seconds == elapsed + 1)
	desk.workspace.how_to_button.pressed.emit()
	assert(desk.how_to_overlay.index == 5)
	desk.how_to_overlay.close_button.pressed.emit()
	assert(not desk.how_to_overlay.visible)
	desk.workspace.rules_button.pressed.emit()
	desk.workspace.how_to_button.pressed.emit()
	assert(not desk.how_to_overlay.visible)
	desk._close_rules()
	desk.workspace.how_to_button.pressed.emit()
	desk._show_start_screen()
	assert(not desk.how_to_overlay.visible and desk.start_screen.visible)
	desk._start_shift()
	assert(not desk.how_to_overlay.visible)
	desk.workspace.how_to_button.pressed.emit()
	desk._start_shift()
	assert(not desk.how_to_overlay.visible and desk.shift.elapsed_seconds == 0)
	desk.queue_free()
	await process_frame
	print("遊び方: 全画像・ページ送り・入力隔離・時計停止・状態復帰に成功")
	quit()
