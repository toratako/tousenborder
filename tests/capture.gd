extends SceneTree
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
	var desk = load("res://scenes/main.tscn").instantiate()
	root.add_child(desk)
	await process_frame
	await _save("start")
	desk.start_button.pressed.emit()
	var item: Dictionary = desk.catalog.cases.filter(func(c): return c.id == "WEB-ADVANCED-001")[0]
	var cases: Array[Dictionary] = [item]
	desk.shift.start(cases)
	await _save("workspace")
	desk.rules_button.pressed.emit()
	await _save("rules")
	desk.rules_close.pressed.emit()
	desk._toggle_tools()
	await _save("tools")
	var external: Dictionary = desk.catalog.tools_for(item).filter(func(t): return t.id == "urlscan_private")[0]
	var url: Dictionary = item.information.filter(func(i): return i.data_type == "url")[0].duplicate(true)
	url.case_id = item.id
	desk._inspect(external, url)
	await _save("external")
	desk.external_skip.pressed.emit()
	for reference in item.references:
		desk._inspect(reference)
	desk.shift.decide(item.ground_truth)
	await _save("audit")
	desk.next.pressed.emit()
	await _save("summary")
	desk.queue_free()
	await process_frame
	print("Learning screenshots: build/screenshots/*.png")
	quit()
