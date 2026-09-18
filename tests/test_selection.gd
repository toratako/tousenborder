extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := Fixtures.catalog()
	assert(catalog.load_pack(), str(catalog.errors))
	assert(catalog.select_cases().size() == Fixtures.pack().problems.size())
	for level in ["very_beginner", "beginner", "intermediate", "advanced"]:
		var selected := catalog.select_cases(level)
		assert(not selected.is_empty() and selected.all(func(c): return c.level == level))
	assert(catalog.select_cases("very_beginner", "file")[0].id == "FIX-VISIBLE-FILE")
	assert(catalog.select_cases("very_beginner", "process").is_empty())
	for os in ["windows", "linux"]:
		var selected := catalog.select_cases("", "", os)
		assert(selected.all(func(c): return c.platform in [os, "common"] and c.investigation_environment == ("linux" if c.platform == "common" else os)))
	var common := catalog.select_cases("", "", "common")
	assert(common.all(func(c): return c.platform == "common" and c.investigation_environment == "linux"))
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	for i in range(desk.difficulty_select.item_count):
		if desk.difficulty_select.get_item_metadata(i) == "beginner":
			desk.difficulty_select.select(i)
			desk.difficulty_select.item_selected.emit(i)
	assert(not desk.start_button.disabled)
	desk.start_button.pressed.emit()
	assert(desk.shift.current().level == "beginner")
	desk._show_start_screen()
	desk.difficulty_select.select(1)
	for i in range(desk.category_select.item_count):
		if desk.category_select.get_item_metadata(i) == "process": desk.category_select.select(i)
	desk._refresh_selection()
	assert(desk.start_button.disabled and desk.start_button.tooltip_text.contains("該当する問題がありません"))
	desk.start_button.pressed.emit()
	assert(not desk.playing)
	desk.queue_free()
	await process_frame
	print("Canonical selection tests passed")
	quit()
