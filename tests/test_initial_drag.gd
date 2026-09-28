extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
## 問題・調査OS・入力の結び付けに応じて基本情報のドラッグ可否を確認する。

func _initialize() -> void:
	_run.call_deferred()

func _show_case(desk, item: Dictionary) -> void:
	desk._clear_desk()
	var cases: Array[Dictionary] = [item]
	desk.shift.start(cases)

func _check_drag(token: InformationToken, enabled: bool) -> void:
	assert(token.information.draggable == enabled)
	assert(token.show_drag_grip == enabled)
	assert(token.tooltip_text.contains("ドラッグ") == enabled)
	assert((token.mouse_default_cursor_shape == Control.CURSOR_DRAG) == enabled)
	if not enabled:
		assert(token._get_drag_data(Vector2.ZERO) == null)

func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	desk._start_shift()
	var file_case: Dictionary = desk.library.cases.filter(func(c): return c.id == "FIX-FILE")[0]
	var original: Dictionary = file_case.duplicate(true)
	_show_case(desk, file_case)
	for token in desk.target_card.tokens:
		_check_drag(token, token.information.id == "File名")
	assert(file_case == original, "表示用の変更で教材を変えない")
	assert(desk.shift.current().information == original.information)

	# 同じ型でも、入力として指定されていない項目や出典は受け付けない。
	var extra := file_case.duplicate(true)
	var same_type: Dictionary = extra.information[0].duplicate(true)
	same_type.id = "別のFile名"
	extra.information.append(same_type)
	var other_source: Dictionary = extra.information[0].duplicate(true)
	other_source.source = "other_source"
	extra.information.append(other_source)
	_show_case(desk, extra)
	_check_drag(desk.target_card.tokens[1], true)
	_check_drag(desk.target_card.tokens[-2], false)
	_check_drag(desk.target_card.tokens[-1], false)

	# 同じ入力でも、その問題で使えるツールと調査OSによって変わる。
	var os_case := file_case.duplicate(true)
	for tool in Fixtures.resources(os_case, "tools"):
		tool.environments = ["windows"]
	os_case.platform = "linux"
	_show_case(desk, os_case)
	_check_drag(desk.target_card.tokens[1], false)
	os_case.platform = "windows"
	_show_case(desk, os_case)
	_check_drag(desk.target_card.tokens[1], true)
	for flag in ["draggable", "tool_input"]:
		var restricted := file_case.duplicate(true)
		restricted.information[0][flag] = false
		_show_case(desk, restricted)
		_check_drag(desk.target_card.tokens[1], false)

	var beginner: Dictionary = desk.library.select_cases("", "file", "", "initial")[0]
	_show_case(desk, beginner)
	assert(desk.tool_buttons.is_empty())
	for token in desk.target_card.tokens:
		_check_drag(token, false)
	_show_case(desk, file_case)
	_check_drag(desk.target_card.tokens[1], true)
	desk.queue_free()
	await process_frame
	print("基本情報のドラッグテスト: 問題別・OS別の対応、入力指定、表示と教材の保持に成功")
	quit()
