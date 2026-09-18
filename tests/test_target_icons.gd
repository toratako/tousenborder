extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	desk.start_button.pressed.emit()
	var category_icons := {"web": "web", "email": "email", "network": "packet",
		"process": "process", "account": "account", "package": "package"}
	var file_icons := {"FIX-FILE": "document", "FIX-HASH": "archive",
		"FIX-PRIVATE-FILE": "executable", "FIX-VISIBLE-FILE": "executable"}
	for item in desk.catalog.cases:
		var cases: Array[Dictionary] = [item]
		desk.shift.start(cases)
		var expected: String = file_icons[item.id] if item.category == "file" else category_icons[item.category]
		assert(desk.target_card.title_icon.texture.resource_path == "res://assets/icons/%s.svg" % expected, item.id)
		assert(desk.target_card.title_label.text == "検査対象")
	for sample in [["photo.PNG", "image"], ["invoice.pdf.EXE", "executable"],
		["bundle.tar.gz", "archive"], ["library.whl", "package"],
		["unknown.xyz", "document"], ["README", "document"]]:
		var item := {"category": "file", "information": [
			{"data_type": "url", "value": "https://example.test/decoy.exe"},
			{"data_type": "file", "value": sample[0]},
			{"data_type": "file", "value": "unrelated.zip"}]}
		assert(desk._target_icon(item) == "res://assets/icons/%s.svg" % sample[1])
	assert(desk._target_icon({"category": "file", "information": []}).ends_with("/document.svg"))
	assert(desk._target_icon({"category": "custom"}).ends_with("/document.svg"))
	desk.queue_free()
	await process_frame
	print("Target icons: all checks passed")
	quit()
