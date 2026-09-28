extends SceneTree
## 固定fixtureとは別に、出題用Packの全問・全資料を実際のUIで辿る。
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)


func _initialize() -> void:
	_run.call_deferred()


func available_input(desk, tool: Dictionary) -> Dictionary:
	for card in desk.workspace.cards:
		for token in card.tokens:
			if Information.accepts(tool, token.payload()):
				return token.payload()
	return { }


func _run() -> void:
	var desk = load("res://scenes/main.tscn").instantiate()
	desk.history_store = preload("res://tests/fixtures.gd").history_store()
	root.add_child(desk)
	await process_frame
	check(desk.library.errors.is_empty(), "出題用Packの読込: " + str(desk.library.errors))
	if not desk.library.errors.is_empty():
		desk.queue_free()
		quit(1)
		return
	check(desk.library.cases.size() == 70, "登録した全問題を読み込む")
	desk._start_shift()
	for item in desk.library.cases:
		check(desk.shift.current().id == item.id, "登録順に出題")
		check(desk.workspace.target_card.title_label.text == "検査対象", "回答前は問題Titleを隠す")
		check(not desk.workspace.target_card.card_data.has("ground_truth"), "判定情報を対象カードに渡さない")
		if item.traits.method in ["initial", "references"]:
			check(
				desk
				.workspace
				.active_tools
				.all(
					func(resource):
						return (
							resource.kind == "references"
							and resource.accepted_information_types.is_empty()
						),
				),
				"入門は入力不要のReferenceだけを調査できる",
			)
			for id in item.required_evidence:
				if id != "initial_information":
					check(
						id in desk.shift.missing_evidence(),
						"Referenceは閲覧前に証拠へ加えない: " + item.id + "/" + id,
					)
		var pending: Array = desk.workspace.active_tools.duplicate()
		var progress := true
		while not pending.is_empty() and progress:
			progress = false
			for tool in pending.duplicate():
				var input := available_input(desk, tool)
				if not tool.accepted_information_types.is_empty() and input.is_empty():
					continue
				if tool.kind != "external_references" and not tool.get("correct_usage", true):
					pending.erase(tool)
					progress = true
					continue
				var before: int = desk.shift.observations.size()
				desk.workspace._inspect(tool, input)
				if tool.kind == "external_references":
					check(desk.external_preview.visible, "送信前確認: " + item.id + "/" + tool.id)
					check(
						desk.external_preview.body.text.contains(Information.display(input.value)),
						"送信内容を表示",
					)
					if tool.correct_usage:
						desk.external_preview.send_button.pressed.emit()
					else:
						desk.external_preview.skip_button.pressed.emit()
				check(
					desk.shift.observations.size() == before + 1,
					"調査記録: " + item.id + "/" + tool.id,
				)
				if desk.shift.observations.size() > before:
					check(desk.shift.observations.back().ok, "調査に成功: " + tool.id)
				pending.erase(tool)
				progress = true
		check(pending.is_empty(), "全資料への到達: " + item.id)
		check(desk.shift.missing_evidence().is_empty(), "許可された調査で証拠が揃う: " + item.id)
		check(desk.shift.decide(item.ground_truth), "判定: " + item.id)
		check(
			desk.audit_overlay.body.text.contains(item.title)
			and desk.audit_overlay.body.text.contains(item.explanation),
			"回答後にTitleと解説を表示",
		)
		desk.audit_overlay.next_button.pressed.emit()
		await process_frame
	check(desk.shift.finished() and desk.shift.score() == 70, "全問題を完了")
	check(desk.shift.unsafe_investigations() == 0, "禁止された外部送信をせずに完了")
	check(desk.summary_screen.save_notice.text.is_empty(), "全問題の履歴保存: " + desk.history_store.error)
	check(desk.history_store.load_entry(desk.shift.session_id).get("records", []).size() == 70, "全問の結果をディスクから再読込")
	desk.queue_free()
	await process_frame
	print("Playable content tests: %d failures" % failures)
	quit(1 if failures else 0)
