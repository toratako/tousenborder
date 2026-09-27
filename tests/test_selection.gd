extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
func _initialize() -> void:
	_run.call_deferred()

func select_value(option: OptionButton, value: String) -> void:
	for i in range(option.item_count):
		if option.get_item_metadata(i) == value:
			option.select(i)
			option.item_selected.emit(i)
			return
	assert(false, "Missing selection: " + value)

func _run() -> void:
	var catalog := Fixtures.catalog()
	assert(catalog.load_pack(), str(catalog.errors))
	assert(catalog.select_cases().size() == Fixtures.pack().problems.size())
	for level in ["very_beginner", "beginner", "beginner_external", "intermediate", "advanced"]:
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
	# 実際の教材で初級の各区分を選び、勤務開始・再開始・既存フィルタを確認する。
	desk = load("res://scenes/main.tscn").instantiate()
	root.add_child(desk)
	await process_frame
	assert(desk.catalog.errors.is_empty(), str(desk.catalog.errors))
	var all_ids := {}
	for level in ContentCatalog.DIFFICULTIES:
		select_value(desk.difficulty_select, level)
		var selected: Array = desk._selected_cases()
		assert(not selected.is_empty())
		assert(selected.all(func(c): return c.level == level))
		var label: String = desk.difficulty_select.text
		var font: Font = desk.difficulty_select.get_theme_font("font")
		var font_size: int = desk.difficulty_select.get_theme_font_size("font_size")
		assert(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 50 <= desk.difficulty_select.size.x, "分類名が省略されない: " + label)
		for item in selected:
			assert(not all_ids.has(item.id), "難易度間で重複しない")
			all_ids[item.id] = true
			var resources: Array = desk.catalog.tools_for(item)
			var has_external: bool = resources.any(func(r): return r.resource_kind == "external_references")
			if level == "beginner":
				assert(not has_external and resources.any(func(r): return r.resource_kind == "tools"))
			elif level == "beginner_reference":
				assert(not resources.is_empty() and resources.all(func(r): return r.resource_kind == "references"))
			elif level == "beginner_external":
				assert(has_external)
		desk.start_button.pressed.emit()
		assert(desk.playing and desk.shift.cases.size() == selected.size())
		assert(desk.shift.cases.all(func(c): return c.level == level))
		desk._start_shift()
		assert(desk.shift.cases.size() == selected.size() and desk.shift.current().level == level)
		desk._show_start_screen()
	assert(all_ids.size() == desk.catalog.cases.size(), "全問がいずれかの難易度から選べる")
	for level in ["beginner_reference", "beginner", "beginner_external"]:
		var category: String = "package" if level == "beginner_reference" else "web"
		select_value(desk.difficulty_select, level)
		select_value(desk.category_select, category)
		select_value(desk.platform_select, "windows")
		assert(not desk.start_button.disabled)
		desk.start_button.pressed.emit()
		assert(desk.shift.cases.all(func(c): return c.level == level and c.category == category and c.platform in ["windows", "common"]))
		desk._show_start_screen()
	select_value(desk.category_select, "file")
	select_value(desk.difficulty_select, "beginner_reference")
	assert(desk.start_button.disabled, "ReferenceのみのFile問題は未登録")
	select_value(desk.category_select, "")
	select_value(desk.platform_select, "")
	select_value(desk.difficulty_select, "")
	assert(desk._selected_cases().size() == desk.catalog.cases.size())
	desk.queue_free()
	await process_frame
	print("Canonical selection tests passed")
	quit()
