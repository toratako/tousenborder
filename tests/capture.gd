extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")


## 通常の描画モードで開始画面と外部照会の確認画面を保存する。
func _initialize() -> void:
	_capture.call_deferred()


func _save(name: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/screenshots/" + name + ".png")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/screenshots")
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	await _save("start")
	desk.start_button.pressed.emit()
	var item: Dictionary = desk.library.cases.filter(
		func(c):
			return c.id == "FIX-PRIVATE-URL",
	)[0]
	var cases: Array[Dictionary] = [item]
	desk.shift.start(cases)
	await _save("workspace")
	desk.rules_button.pressed.emit()
	await _save("rules")
	desk.rules_close.pressed.emit()
	var external: Dictionary = desk.library.tools_for(item).filter(
		func(t):
			return t.id == "urlscan_private",
	)[0]
	var url: Dictionary = item.information.filter(
		func(i):
			return i.data_type == "url",
	)[0].duplicate(true)
	url.case_id = item.id
	desk._inspect(external, url)
	await _save("external")
	desk.external_skip.pressed.emit()
	for reference in Fixtures.resources(item, "references"):
		desk._inspect(reference)
	await _save("references")
	desk.shift.decide(item.ground_truth)
	await _save("audit")
	desk.next.pressed.emit()
	await _save("summary")
	desk._start_shift()
	var dense_cases: Array[Dictionary] = desk.library.cases.filter(
		func(c):
			return c.id == "FIX-PRIVATE-FILE",
	)
	desk.shift.start(dense_cases)
	await _save("dense_panel")
	desk.tool_scroll.scroll_vertical = int(desk.tool_scroll.get_v_scroll_bar().max_value)
	await _save("dense_panel_scrolled")
	desk.queue_free()
	await process_frame
	print("Learning screenshots: build/screenshots/*.png")
	quit()
