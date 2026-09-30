extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	desk._start_shift()
	var items: Array[Dictionary] = desk.library.cases.slice(0, 3)
	desk.shift.start(items)
	for i in items.size():
		var expected: String = desk.shift.current().ground_truth
		desk.shift.decide(("block" if expected == "allow" else "allow") if i == 1 else expected)
		desk.audit_overlay.next_button.pressed.emit()
	var saved: Dictionary = desk.completed_snapshot.duplicate(true)
	saved.records[0].title = "[b]長い問題名[/b]".repeat(8)
	saved.records[0].explanation = "説明文は省略せず、すべて表示します。\n".repeat(60) + "理由の末尾 [b]そのまま表示[/b]"
	saved.records[0].observations.append({
		"tool": "外部照会", "ok": true, "correct_usage": false,
		"reason": "機密情報を送信したため不適切です。",
	})
	for history in [false, true]:
		desk._display_summary(saved, history)
		desk.summary_screen.select_tab(1)
		for i in 4:
			await process_frame
		var review: RichTextLabel = desk.summary_screen.review
		var text := review.get_parsed_text()
		check(not text.contains("理由の末尾") and text.contains("▶ 理由を表示"), "理由は初期状態で折りたたむ")
		check(text.contains("調査方法に注意"), "折りたたみ中も調査の注意は表示")
		review.meta_clicked.emit(0)
		for i in 3:
			await process_frame
		text = review.get_parsed_text()
		check(text.contains(saved.records[0].title), "長い問題名とタグ表記をそのまま表示")
		check(text.contains(saved.records[0].explanation), "理由を末尾まで全文表示")
		check(text.contains("✓ 正解") and text.contains("✕ 誤判定"), "記号と正誤を表示")
		check(text.contains("調査方法に注意") and text.contains("機密情報を送信したため不適切です。"), "調査の注意と理由を保持")
		check(not text.contains(saved.records[0].id), "案件番号を表示しない")
		check(review.get_content_height() > review.size.y, "長文を一覧全体でスクロール")
		review.get_v_scroll_bar().value = review.get_v_scroll_bar().max_value
		await process_frame
		check(review.get_v_scroll_bar().value > 0, "末尾へスクロールできる")
		check(review.get_global_rect().end.y < desk.summary_screen.home.global_position.y, "本文と下部ボタンが重ならない")
		desk.summary_screen.select_tab(1, "", [1])
		await process_frame
		text = review.get_parsed_text()
		check(not text.contains(saved.records[0].title) and text.contains(saved.records[1].title), "絞込み後は対象だけ表示")
		check(review.get_v_scroll_bar().value == 0, "絞込み時にスクロール位置を戻す")
		desk.summary_screen.select_tab(1)
		check(review.get_parsed_text().contains("理由の末尾"), "絞込みを戻しても展開状態を保持")
		review.meta_clicked.emit(0)
		check(not review.get_parsed_text().contains("理由の末尾"), "同じリンクで理由を閉じる")
		review.meta_clicked.emit(1)
		check(review.get_parsed_text().contains(saved.records[1].explanation), "別の問題の理由も展開できる")
		check(not review.get_parsed_text().contains("理由の末尾"), "他の問題を勝手に展開しない")
	var hidden := saved.duplicate(true)
	hidden.feedback = { "show_reason": false, "show_expected": false }
	desk._display_summary(hidden, true)
	desk.summary_screen.select_tab(1)
	var hidden_text: String = desk.summary_screen.review.get_parsed_text()
	check(not hidden_text.contains("理由の末尾") and not hidden_text.contains("機密情報"), "過去の理由非表示設定を尊重")
	check(hidden_text.contains("あなたは") and not hidden_text.contains("正しく判断"), "正解非表示設定を尊重")
	desk.queue_free()
	await process_frame
	print("Review cards tests: %d failures" % failures)
	quit(1 if failures else 0)
