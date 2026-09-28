extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")


## 遊び方スライド用の実画面。加工は scripts/build_how_to_slides.py。
func _initialize() -> void:
	_capture.call_deferred()


func _save(name: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/screenshots/how_to/" + name + ".png")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/screenshots/how_to")
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	desk._start_shift()
	desk.set_process(false)
	var cases: Array[Dictionary] = desk.library.cases.filter(
		func(c):
			return c.id == "FIX-FILE",
	)
	desk.shift.start(cases)
	await _save("target")
	var token: InformationToken = desk.workspace.target_card.tokens.filter(
		func(t):
			return t.information.id == "File名",
	)[0]
	token.selected.emit(token.payload())
	await _save("tools")
	var file_button: Button = desk.workspace.tool_buttons.filter(
		func(b):
			return b.tool.id == "file",
	)[0]
	file_button.pressed.emit()
	desk.workspace.cards.back().position = Vector2(524, 20)
	await _save("result")
	var reference: Button = desk.workspace.tool_buttons.filter(
		func(b):
			return b.tool.id == "document_format",
	)[0]
	reference.pressed.emit()
	desk.workspace.cards.back().position = Vector2(524, 320)
	await _save("compare")
	desk.workspace.target_card._drop_data(Vector2.ZERO, desk.workspace.get_stamp("block").payload())
	await create_timer(0.5).timeout
	await _save("audit")
	cases = desk.library.cases.filter(
		func(c):
			return c.id == "FIX-PRIVATE-URL",
	)
	desk.shift.start(cases)
	var url: InformationToken = desk.workspace.target_card.tokens.filter(
		func(t):
			return t.information.data_type == "url",
	)[0]
	desk.workspace._select_information(url.payload())
	var external: Button = desk.workspace.tool_buttons.filter(
		func(b):
			return b.tool.id == "urlscan_private",
	)[0]
	external.pressed.emit()
	await _save("external")
	desk.external_preview.skip_button.pressed.emit()
	if ResourceLoader.exists(desk.how_to_overlay.HOW_TO_SLIDES[0]):
		desk.workspace.how_to_button.pressed.emit()
		await _save("gallery")
		desk.how_to_overlay.change_slide(5)
		await _save("gallery_last")
	desk.queue_free()
	await process_frame
	print("How-to screenshots: build/screenshots/how_to/*.png")
	quit()
