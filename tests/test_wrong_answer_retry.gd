extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
const Retry = preload("res://src/app/wrong_answer_retry.gd")
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)


func texts(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children():
		result += texts(child)
	return result


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	desk._start_shift()
	var items: Array[Dictionary] = desk.library.cases.slice(0, 3)
	desk.shift.start(items)
	for i in items.size():
		desk.shift.tick(10)
		desk.shift.decide(
			(
				items[i].ground_truth
				if i == 1
				else ("allow" if items[i].ground_truth == "block" else "block")
			)
		)
		desk.audit_overlay.next_button.pressed.emit()
	var saved: Dictionary = desk.completed_snapshot.duplicate(true)
	check(HistoryStore.validate(saved).is_empty(), "通常勤務の保存形式")
	check(desk.summary_screen.restart.text == "同じ問題に再挑戦", "右下の再挑戦ボタンは出題内容に沿った表示")
	check(
		desk.summary_screen.retry_wrong.text.contains("2問")
		and not desk.summary_screen.retry_wrong.disabled,
		"今回の誤答2問を案内",
	)
	var before := saved.duplicate(true)
	var plan := Retry.plan(saved, desk.library)
	check(
		plan.cases.map(
			func(item):
				return item.id,
		)
		== [items[0].id, items[2].id],
		"誤答のみ・元の出題順",
	)
	plan.cases[0].title = "mutation"
	check(desk.library.cases[0].title != "mutation" and saved == before, "教材と履歴を変更しない")
	var duplicate := saved.duplicate(true)
	duplicate.records.append(saved.records[0].duplicate(true))
	check(Retry.plan(duplicate, desk.library).cases.size() == 2, "重複問題を一度だけ出題")
	var missing := saved.duplicate(true)
	missing.records[0].id = "deleted"
	plan = Retry.plan(missing, desk.library)
	check(plan.cases.size() == 1 and plan.missing == 1, "削除された問題を除外")
	missing.records[2].id = "deleted-too"
	check(Retry.plan(missing, desk.library).cases.is_empty(), "全件削除なら再挑戦できない")
	var different := saved.duplicate(true)
	different.records[0].source_id = "another-source"
	different.records[2].source_id = "another-source"
	check(Retry.plan(different, desk.library).cases.is_empty(), "異なる教材の同じIDを出題しない")
	desk.library.errors.append("test")
	check(Retry.plan(saved, desk.library).cases.size() == 2, "追加教材の失敗でも既存教材は出題可能")
	desk.library.errors.clear()
	# 実際に保存した履歴から開始する。タイトル画面の選択条件には依存しない。
	desk.summary_screen.home.pressed.emit()
	desk.start_screen.history_button.pressed.emit()
	desk._open_history_entry(saved.session_id)
	check(desk.summary_from_history, "過去の履歴から再挑戦へ")
	desk.library.cases[0].title = "更新された問題"
	desk.summary_screen.retry_wrong.pressed.emit()
	check(
		desk.workspace.playing and not desk.summary_from_history
		and not desk.history_overlay.visible and not is_instance_valid(desk.summary_screen),
		"履歴から勤務画面へ遷移",
	)
	check(desk.shift.cases.size() == 2 and desk.shift.current().title == "更新された問題", "現在の教材で誤答だけ出題")
	check(
		desk.shift.records.is_empty() and desk.shift.observations.is_empty()
		and desk.shift.elapsed_seconds == 0,
		"記録・調査・時計を初期化",
	)
	check(
		desk.retry_source_id == saved.session_id and desk.shift.session_id != saved.session_id,
		"別勤務IDと元履歴ID",
	)
	check(
		desk.workspace.displayed_case == items[0].id
		and is_instance_valid(desk.workspace.target_card)
		and desk.workspace.selected_information.is_empty(),
		"通常の案件表示と入力選択を初期化",
	)
	var first_id: String = desk.shift.session_id
	desk.shift.tick(9)
	desk._toggle_menu()
	check(desk.pause_menu.visible, "再挑戦中も一時停止できる")
	desk.pause_menu.restart_button.pressed.emit()
	check(
		desk.shift.cases.size() == 2 and desk.shift.elapsed_seconds == 0
		and desk.shift.session_id != first_id,
		"一時停止からの再開始は誤答の集合を維持",
	)
	for item in desk.shift.cases:
		desk.shift.decide(item.ground_truth)
		desk.audit_overlay.next_button.pressed.emit()
	var retried: Dictionary = desk.completed_snapshot.duplicate(true)
	check(
		retried.get("retry_of") == saved.session_id and HistoryStore.validate(retried).is_empty(),
		"再挑戦の履歴を正しく保存",
	)
	check(
		desk.summary_screen.title.text == "再挑戦の結果" and desk.summary_screen.retry_wrong.disabled,
		"全問正解なら誤答再挑戦は無効",
	)
	check(
		texts(desk.summary_screen.analysis).contains("復習者")
		and not texts(desk.summary_screen.analysis).contains("セキュリティチャレンジャー"),
		"再挑戦の分析は復習者と表示",
	)
	check(retried.selection == Retry.selection(desk.shift.cases, desk.library), "履歴の出題条件は実際の問題から作成")
	check(desk.history_store.list_entries().size() == 2, "元の履歴を上書きせず別途保存")
	# 保存時のJSON変換で時刻の小数部が丸められる。
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(saved, "  "))
	check(
		ContentSchema._equal(desk.history_store.load_entry(saved.session_id), serialized),
		"元の履歴を保持",
	)
	var index_path: String = desk.history_store.directory.path_join(
		retried.session_id + HistoryStore.INDEX_SUFFIX
	)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	check(index.get("retry_of") == saved.session_id, "索引にも再挑戦の識別情報")
	check(HistoryStore._valid_index(index, retried.session_id), "再挑戦索引のスキーマ")
	desk.summary_screen.restart.pressed.emit()
	check(
		desk.shift.cases.size() == 2 and desk.completed_snapshot.is_empty()
		and desk.retry_source_id == retried.session_id,
		"結果から同じ対象を直前の勤務の再挑戦として開始",
	)
	desk._show_start_screen()
	check(desk.retry_cases.is_empty() and desk.retry_source_id.is_empty(), "タイトルで再挑戦状態を解除")
	desk._start_shift()
	check(desk.shift.cases.size() == desk.start_screen.selected_cases().size(), "通常の勤務はタイトルの条件で出題")
	desk._show_start_screen()
	desk.start_screen.history_button.pressed.emit()
	check(
		desk
		.history_overlay
		.entries_list
		.get_children()
		.any(
			func(node):
				return node is Button and node.text.begins_with("再挑戦"),
		),
		"履歴一覧で再挑戦を識別",
	)
	desk._open_history_entry(retried.session_id)
	check(
		desk.summary_screen.title.text.contains("再挑戦") and desk.summary_screen.retry_wrong.disabled,
		"再挑戦結果も後から閲覧可能",
	)
	check(texts(desk.summary_screen.analysis).contains("復習者"), "履歴から見た再挑戦の分析も復習者と表示")
	desk.queue_free()
	await process_frame
	print("Wrong answer retry tests: %d failures" % failures)
	quit(1 if failures else 0)
