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
	assert(desk.library.difficulties.keys() == ["very_beginner", "beginner", "applied"])
	var difficulty_option: OptionButton = desk.start_screen.difficulty_select
	assert(difficulty_option.item_count == 4)
	for i in 4:
		assert(difficulty_option.get_item_text(i) == ["すべて", "超初級", "初級", "応用"][i])
	for pair in [["very_beginner", 8], ["beginner", 51], ["applied", 16]]:
		select_value(difficulty_option, pair[0])
		var selected: Array = desk.start_screen.selected_cases()
		assert(selected.size() == pair[1])
		assert(selected.all(func(item): return item.difficulty == pair[0]))
		desk.start_screen.start_button.pressed.emit()
		assert(desk.shift.cases.size() == pair[1])
		assert(desk.shift.decide(desk.shift.current().ground_truth))
		assert(desk.shift.records[0].level == pair[0])
		desk._show_start_screen()
	select_value(desk.start_screen.difficulty_select, "")
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
	assert(desk.library.cases.all(func(item): return all_ids.has(item.id)))
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
	var pack: Dictionary = desk.library.packs[0]
	select_value(desk.start_screen.pack_select, pack.key)
	assert(
		desk.start_screen.selected_cases().size() == 20
		and desk.start_screen.category_select.disabled and desk.start_screen.method_select.disabled
	)
	desk.start_screen.start_button.pressed.emit()
	var drawn_ids: Array = desk.shift.cases.map(func(item): return item.id)
	assert(drawn_ids.size() == 20)
	assert(drawn_ids.all(func(id): return id in pack.problems))
	assert(desk.shift.decide(desk.shift.current().ground_truth))
	desk.pause_menu.restart_requested.emit()
	assert(desk.shift.records.is_empty() and desk.shift.index == 0)
	assert(desk.shift.cases.map(func(item): return item.id) == drawn_ids)
	for i in 20:
		assert(desk.shift.decide(desk.shift.current().ground_truth))
		desk.audit_overlay.next_button.pressed.emit()
	assert(desk.completed_snapshot.records.size() == 20)
	assert(HistoryStore.validate(desk.completed_snapshot).is_empty())
	desk.summary_screen.restart_requested.emit()
	assert(desk.shift.cases.map(func(item): return item.id) == drawn_ids)
	desk._show_start_screen()
	var unrated := Fixtures.raw("FIX-VISIBLE-FILE")
	unrated.erase("difficulty")
	assert(desk.library.add_source(Fixtures.source([unrated], "unrated-selection")))
	desk.start_screen.refresh_options()
	assert(desk.library.difficulties.keys() == ["very_beginner", "beginner", "applied", "unrated"])
	assert(difficulty_option.get_item_text(4) == "未評価")
	for option in [desk.start_screen.pack_select, desk.start_screen.category_select, desk.start_screen.platform_select]:
		select_value(option, "")
	select_value(difficulty_option, "unrated")
	assert(desk.start_screen.selected_cases().size() == 1)
	assert(desk.start_screen.selected_cases()[0].id == unrated.id)
	desk.queue_free()
	await process_frame
	print("Selection tests passed")
	quit()
