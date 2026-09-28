extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var desk = load("res://scenes/main.tscn").instantiate()
	root.add_child(desk)
	desk._start_shift()
	var failures := 0
	for item in desk.library.cases:
		var cases: Array[Dictionary] = [item]
		desk.shift.start(cases)
		for frame in range(8): await process_frame
		for button in desk.tool_buttons:
			if not button.visible: continue
			if button.heading.text != button.tool.label or button.heading.size.y < button.heading.get_line_height() or button.heading.size.x <= 0:
				printerr("Missing heading: ", item.id, " / ", button.tool.id, " size=", button.heading.size)
				failures += 1
			if button.hint.visible and button.hint.position.y < button.heading.get_rect().end.y:
				printerr("Overlapping tool hint: ", item.id, " / ", button.tool.id)
				failures += 1
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/screenshots/tool-labels.png")
	desk.queue_free()
	await process_frame
	print("Tool label failures: ", failures)
	quit(1 if failures else 0)
