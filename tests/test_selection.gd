extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")


func _initialize() -> void:
	_run.call_deferred()


func select_value(option: OptionButton, value: String) -> void:
	for i in option.item_count:
		if option.get_item_metadata(i) == value:
			option.select(i)
			option.item_selected.emit(i)
			return
	assert(false, "Missing selection: " + value)


func _run() -> void:
	var library := Fixtures.library()
	assert(library.load_builtin(), str(library.errors))
	assert(library.select_cases().size() == Fixtures.count())
	for difficulty in library.difficulties:
		assert(
			library.select_cases(difficulty).all(
				func(c):
					return c.difficulty == difficulty,
			)
		)
	for os in ["windows", "linux", "common"]:
		assert(
			library
			.select_cases("", "", os)
			.all(
				func(c):
					return (
						c.platform in [os, "common"]
						and c.investigation_environment
						== ("linux" if c.platform == "common" else os)
					),
			)
		)
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	select_value(desk.start_screen.difficulty_select, "beginner")
	desk.start_screen.start_button.pressed.emit()
	assert(
		desk.workspace.playing
		and desk.shift.cases.all(
			func(c):
				return c.difficulty == "beginner",
		)
	)
	desk._show_start_screen()
	select_value(desk.start_screen.method_select, "initial")
	select_value(desk.start_screen.category_select, "process")
	assert(desk.start_screen.start_button.disabled)
	desk.queue_free()
	await process_frame
	desk = load("res://scenes/main.tscn").instantiate()
	desk.import_store = ContentImportStore.new(Fixtures.temporary_directory("imports"))
	desk.history_store = Fixtures.history_store()
	root.add_child(desk)
	await process_frame
	assert(desk.library.errors.is_empty(), str(desk.library.errors))
	assert(
		desk.start_screen.difficulty_select.item_count == 2
		and desk.library.difficulties.has("unrated")
	)
	var all_ids := { }
	for method in desk.library.methods:
		select_value(desk.start_screen.method_select, method)
		var selected: Array = desk.start_screen.selected_cases()
		assert(not selected.is_empty())
		for item in selected:
			assert(item.traits.method == method and not all_ids.has(item.id))
			all_ids[item.id] = true
		desk.start_screen.start_button.pressed.emit()
		assert(desk.workspace.playing and desk.shift.cases.size() == selected.size())
		desk._start_shift()
		assert(desk.shift.cases.size() == selected.size())
		desk._show_start_screen()
	assert(all_ids.size() == 70)
	select_value(desk.start_screen.method_select, "")
	select_value(desk.start_screen.category_select, "file")
	select_value(desk.start_screen.platform_select, "linux")
	assert(
		desk
		.start_screen
		.selected_cases()
		.all(
			func(c):
				return c.category == "file" and c.platform in ["common", "linux"],
		)
	)
	select_value(desk.start_screen.pack_select, desk.library.packs[0].key)
	assert(
		desk.start_screen.selected_cases().size() == 70
		and desk.start_screen.category_select.disabled and desk.start_screen.method_select.disabled
	)
	desk.start_screen.start_button.pressed.emit()
	assert(desk.shift.current().id == desk.library.packs[0].chapters[0].problems[0])
	desk.queue_free()
	await process_frame
	print("Selection tests passed")
	quit()
