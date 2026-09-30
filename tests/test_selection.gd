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


func check_difficulty_selection(desk) -> void:
	var option: OptionButton = desk.start_screen.difficulty_select
	var index := 1
	assert(option.get_item_metadata(0) == "" and option.get_item_text(0) == "すべて")
	for pair in [["very_beginner", "超初級"], ["beginner", "初級"], ["applied", "応用"], ["unrated", "未評価"]]:
		var expected: Array = desk.library.cases.filter(func(item): return item.difficulty == pair[0])
		if expected.is_empty():
			continue
		assert(option.get_item_metadata(index) == pair[0] and option.get_item_text(index) == pair[1])
		index += 1
		select_value(option, pair[0])
		var expected_keys: Array = expected.map(func(item): return item.key)
		assert(desk.start_screen.selected_cases().map(func(item): return item.key) == expected_keys)
		desk.start_screen.start_button.pressed.emit()
		assert(desk.shift.cases.map(func(item): return item.key) == expected_keys)
		assert(desk.shift.decide(desk.shift.current().ground_truth))
		assert(desk.shift.records[0].level == pair[0])
		desk._show_start_screen()
	assert(option.item_count == index)
	select_value(option, "")


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
	var difficulty_option: OptionButton = desk.start_screen.difficulty_select
	check_difficulty_selection(desk)
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
	assert(desk.library.add_source(Fixtures.sampling_source()))
	desk.start_screen.refresh_options()
	check_difficulty_selection(desk)
	select_value(desk.start_screen.category_select, "file")
	select_value(desk.start_screen.platform_select, "common")
	assert(
		desk
		.start_screen
		.selected_cases()
		.all(
			func(c):
				return c.category == "file" and c.platform == "common",
		)
	)
	var pack: Dictionary = desk.library.packs.filter(func(item): return item.key == "sampling/pack/random")[0]
	# 1問だけの難易度を上で完了していても、抽選履歴の検証に混ぜない。
	desk.history_store = Fixtures.history_store()
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
		var expected: String = desk.shift.current().ground_truth
		var verdict := ("block" if expected == "allow" else "allow") if i == 0 else expected
		assert(desk.shift.decide(verdict))
		desk.audit_overlay.next_button.pressed.emit()
	assert(desk.completed_snapshot.records.size() == 20)
	assert(HistoryStore.validate(desk.completed_snapshot).is_empty())
	var saved: Dictionary = desk.history_store.load_entry(desk.completed_snapshot.session_id)
	assert(saved.selection.mode == "random" and saved.pack.title == pack.title)
	assert(saved.selection.level == desk.completed_snapshot.selection.level)
	var entries: Array[Dictionary] = desk.history_store.list_summaries()
	assert(entries.size() == 1 and entries[0].selection.mode == "random")
	desk.history_overlay.show_entries(entries, [])
	var caption: String = desk.history_overlay.entries_list.get_child(0).text
	assert(caption.split("\n")[1].begins_with("ランダム演習 / "))
	var legacy: Dictionary = saved.duplicate(true)
	legacy.selection.erase("mode")
	assert(HistoryStore.validate(legacy).is_empty())
	var legacy_entries: Array[Dictionary] = [legacy]
	desk.history_overlay.show_entries(legacy_entries, [])
	caption = desk.history_overlay.entries_list.get_child(0).text
	assert(caption.split("\n")[1].begins_with(str(legacy.selection.level.label) + " / "))
	desk.history_overlay.hide()
	desk.summary_screen.restart_requested.emit()
	assert(desk.shift.cases.map(func(item): return item.id) == drawn_ids)
	assert(desk.random_exercise)
	desk._display_summary(saved, false)
	desk._retry_wrong_answers()
	assert(not desk.random_exercise and desk.shift.cases.size() == 1)
	assert(desk.shift.decide(desk.shift.current().ground_truth))
	desk.audit_overlay.next_button.pressed.emit()
	assert(not desk.completed_snapshot.selection.has("mode"))
	desk._show_start_screen()
	assert(not desk.random_exercise)
	var before_unrated: Array = desk.library.cases.filter(func(item): return item.difficulty == "unrated").map(func(item): return item.key)
	var unrated := Fixtures.raw("FIX-VISIBLE-FILE")
	unrated.erase("difficulty")
	assert(desk.library.add_source(Fixtures.source([unrated], "unrated-selection")))
	desk.start_screen.refresh_options()
	assert(desk.library.difficulties.keys() == ["very_beginner", "beginner", "applied", "unrated"])
	assert(difficulty_option.get_item_text(4) == "未評価")
	for option in [desk.start_screen.pack_select, desk.start_screen.category_select, desk.start_screen.platform_select]:
		select_value(option, "")
	select_value(difficulty_option, "unrated")
	var selected_unrated: Array = desk.start_screen.selected_cases().map(func(item): return item.key)
	assert(selected_unrated.size() == before_unrated.size() + 1)
	assert(before_unrated.all(func(key): return key in selected_unrated))
	assert("unrated-selection/" + unrated.id in selected_unrated)
	desk.queue_free()
	await process_frame
	print("Selection tests passed")
	quit()
