extends SceneTree
## 任意の表示確認。ディスプレイへの接続が必要。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var desk = load("res://scenes/main.tscn").instantiate()
	root.add_child(desk)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/packets-start.png")
	desk.license_button.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/packets-licenses.png")
	desk.license_close.pressed.emit()
	desk.start_button.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("/tmp/packets-please.png")
	desk.tool_buttons[0].pressed.emit()
	desk.deny.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/packets-debrief.png")
	desk.next.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/packets-file.png")
	while not desk.shift.finished():
		desk.approve.pressed.emit()
		desk.next.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/packets-summary.png")
	desk.summary_restart.pressed.emit()
	desk.set_process(false)
	desk._process(300)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/packets-timeout.png")
	quit(error)
