extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
var failures := 0

class SupportCatalog extends ContentCatalog:
	func _read(path: String) -> Variant:
		if path == DEFAULT_PACK:
			return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/learning-support/pack.json"))
		if path == "res://data/problems/FILE-LINUX-BEGINNER-002.json":
			return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/learning-support/problem.json"))
		return super._read(path)

class FailingStore extends HistoryStore:
	func save_completed(_data: Dictionary) -> bool:
		error = "simulated write failure"
		return false

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func input_for(desk, tool: Dictionary) -> Dictionary:
	for card in desk.cards:
		for token in card.tokens:
			if Information.accepts(tool, token.payload()): return token.payload()
	return {}

func terms(desk) -> Array[Dictionary]:
	return LearningGlossary.visible_terms(desk.shift.current(), desk.catalog.glossary_terms, desk.active_tools, desk.glossary_viewed)

func write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var desk = load("res://scenes/main.tscn").instantiate()
	var store := Fixtures.history_store()
	desk.catalog = SupportCatalog.new()
	desk.history_store = store
	root.add_child(desk)
	await process_frame
	check(desk.catalog.errors.is_empty(), "標準教材と用語辞書を読込")
	var schema: Dictionary = ContentSchema.read_schema(ContentSchema.PROBLEM)
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/learning-support/problem.json"))
	for invalid in ["unknown_term", "wrong_source", "wrong_submission", "duplicate_term", "duplicate_occurrence"]:
		var candidate := sample.duplicate(true)
		match invalid:
			"unknown_term": candidate.glossary[0].term_id = "missing"
			"wrong_source": candidate.glossary[0].occurrences = [{"source_id": "missing", "section": "result"}]
			"wrong_submission": candidate.glossary[0].occurrences = [{"source_id": "vendor_hash", "section": "submission"}]
			"duplicate_term": candidate.glossary.append(candidate.glossary[0].duplicate(true))
			"duplicate_occurrence": candidate.glossary[0].occurrences.append(candidate.glossary[0].occurrences[0].duplicate(true))
		var structural := ContentSchema.check(candidate, schema)
		check(not structural.is_empty() or not ProblemData.normalize(candidate, desk.catalog, schema).is_empty(), "Godot側でも教材の不備を拒否: " + invalid)
	desk._start_shift()
	var cases: Array[Dictionary] = desk.catalog.cases.filter(func(c): return c.id == "FILE-LINUX-BEGINNER-002")
	desk.shift.start(cases)
	var hash_tool: Dictionary = desk.shift.current().tools[0]
	var sha: Dictionary = terms(desk).filter(func(t): return t.id == "sha256")[0]
	check(not sha.tags.any(func(tag): return "実行結果" in tag), "未調査のタグを表示しない")
	desk.glossary_button.pressed.emit()
	check(desk.glossary_overlay.visible, "用語集を開く")
	var column: VBoxContainer = desk.glossary_list.get_child(0)
	var toggle: Button = column.get_child(0)
	var description: Label = column.get_child(1)
	check(not description.visible and not toggle.button_pressed, "最初は折りたたみ")
	toggle.button_pressed = true
	check(description.visible, "クリック相当で説明を展開")
	var elapsed: float = desk.shift.elapsed_seconds
	var before: int = desk.shift.observations.size()
	desk._process(10)
	desk._inspect(hash_tool, input_for(desk, hash_tool))
	check(desk.shift.elapsed_seconds == elapsed and desk.shift.observations.size() == before, "用語閲覧中は時計・調査を停止")
	check(not desk._can_stamp(desk.get_stamp("allow").payload()), "用語閲覧中の押印を拒否")
	check(desk.tool_buttons.all(func(button): return button.disabled), "用語閲覧中は背面ToolのD&Dも無効")
	desk._open_rules()
	desk._open_how_to()
	check(not desk.rules_overlay.visible and not desk.how_to_overlay.visible, "モーダルの重ね開きを拒否")
	check(desk.glossary_close.focus_next == desk.glossary_close.get_path_to(desk.glossary_search), "閉じるから検索へTab移動")
	check(desk.glossary_search.focus_next == desk.glossary_search.get_path_to(toggle), "検索から用語へTab移動")
	desk.glossary_search.text = "  fIlE  "
	desk.glossary_search.text_changed.emit(desk.glossary_search.text)
	check(column.visible and description.visible, "大小文字・前後空白を無視して検索し、開閉状態を維持")
	desk.glossary_search.text = "文書やプログラム"
	desk.glossary_search.text_changed.emit(desk.glossary_search.text)
	check(column.visible, "説明文からも検索できる")
	desk.glossary_search.text = "別経路確認"
	desk.glossary_search.text_changed.emit(desk.glossary_search.text)
	check(desk.glossary_empty.visible and desk.glossary_count.text.begins_with("0 /"), "未閲覧の結果用語は検索しても表示しない")
	check(desk.glossary_search.focus_next == desk.glossary_search.get_path_to(desk.glossary_close), "検索結果なしでもTab移動を閉じた画面内に保つ")
	desk.glossary_search.text = ""
	desk.glossary_search.text_changed.emit("")
	check(not desk.glossary_empty.visible and column.visible and description.visible, "検索解除で一覧と展開状態を復元")
	desk.glossary_search.text = "file"
	desk.glossary_search.text_changed.emit("file")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	desk._input(cancel)
	check(not desk.glossary_overlay.visible and not desk.pause_menu.visible, "ESCは用語集だけを閉じる")
	desk._open_glossary()
	check(desk.glossary_search.text == "file", "同じ問題の再表示では検索語を保持")
	check(desk.glossary_list.get_child(0).get_child(1).visible, "同じ問題では展開状態を保持")
	desk._close_glossary()
	desk._inspect(hash_tool, input_for(desk, hash_tool))
	desk._inspect(hash_tool, input_for(desk, hash_tool))
	sha = terms(desk).filter(func(t): return t.id == "sha256")[0]
	check(sha.tags.count("sha256sumの実行結果") == 1, "結果表示でタグを一度だけ追加")
	var external: Dictionary = desk.shift.current().external_references[0].duplicate(true)
	desk._inspect(external, input_for(desk, external))
	check(desk.glossary_viewed.has(LearningGlossary.key(external.id, "submission")), "送信確認を閲覧済みにする")
	desk._finish_external(false)
	check(not desk.glossary_viewed.has(LearningGlossary.key(external.id, "result")), "見送りで結果用語を解禁しない")
	external.correct_usage = false
	desk._inspect(external, input_for(desk, external))
	desk._finish_external(true)
	check(desk.glossary_viewed.has(LearningGlossary.key(external.id, "result")), "不適切な送信でも表示された結果の用語は解禁")
	check(desk.shift.unsafe_investigations() == 1, "用語の閲覧と不適切な調査の集計は独立")
	check(store.list_entries().is_empty(), "途中の勤務は保存しない")
	check(desk.shift.decide(desk.shift.current().ground_truth), "調査後に判定")
	desk.next.pressed.emit()
	await process_frame
	check(not desk.summary_retry.visible and desk.summary_save_notice.text.is_empty(), "勤務終了時の保存に成功: " + store.error)
	var entries := store.list_entries()
	check(entries.size() == 1, "一勤務一件の履歴")
	if entries.is_empty():
		desk.queue_free()
		quit(1)
		return
	var saved: Dictionary = entries[0]
	var invalid_snapshot := saved.duplicate(true)
	invalid_snapshot.stats.correct += 1
	check(not HistoryStore.validate(invalid_snapshot).is_empty(), "集計の改変を検出")
	check(saved.stats.unsafe == 1, "不適切な利用を保存")
	desk._show_summary()
	check(store.save_completed(saved) and store.list_entries().size() == 1, "再表示・再保存でも重複しない")
	var conflicting := saved.duplicate(true)
	conflicting.records[0].explanation = "different"
	check(not store.save_completed(conflicting), "同じIDの異なるデータを上書きしない")
	var old_records: Array = desk.shift.records.duplicate(true)
	desk.summary_home.pressed.emit()
	desk.catalog.cases.clear()
	desk.catalog.glossary_terms.clear()
	desk.history_button.pressed.emit()
	check(desk.history_overlay.visible, "タイトルから勤務履歴へ")
	desk._open_history_entry(saved.session_id)
	check(desk.summary_from_history and desk.summary_review.get_parsed_text().contains(saved.records[0].explanation), "教材がなくても当時の監査所見を表示")
	var hidden := saved.duplicate(true)
	hidden.feedback = {"show_reason": false, "show_expected": false}
	desk._display_summary(hidden, true)
	check(not desk.summary_review.get_parsed_text().contains("正しい判定"), "履歴でも当時の表示設定を尊重")
	desk._display_summary(saved, true)
	check(not desk.summary_review.get_parsed_text().contains("初期情報・調査記録を"), "履歴に追加の展開リンクを表示しない")
	check(desk.shift.records == old_records, "履歴閲覧で現在の勤務記録を変更しない")
	desk.summary_home.pressed.emit()
	check(desk.history_overlay.visible, "詳細から履歴一覧へ戻る")
	desk._close_history()
	# ディスクを読み直す新しいStoreでも再現でき、破損・未知版だけを除外する。
	var reopened := HistoryStore.new(store.directory)
	check(ContentSchema._equal(reopened.load_entry(saved.session_id), saved), "再読込でスナップショットが一致")
	var unknown := saved.duplicate(true)
	unknown.session_id = "a".repeat(32)
	unknown.schema_version = 99
	write_json(store.directory.path_join(unknown.session_id + ".json"), unknown)
	write_json(store.directory.path_join("b".repeat(32) + ".json"), {})
	write_json(store.directory.path_join("ignored.json.tmp"), {})
	check(reopened.list_entries().size() == 1 and reopened.warnings.size() == 2, "壊れた履歴・未知の版を除外し一時ファイルを無視")
	check(not reopened.save_completed({}), "不完全な勤務データを保存しない")
	check(reopened.load_entry("../escape").is_empty(), "履歴IDのパス指定を拒否")
	var newer := saved.duplicate(true)
	newer.session_id = "c".repeat(32)
	newer.completed_at += 10
	check(reopened.save_completed(newer) and reopened.list_entries()[0].session_id == newer.session_id, "新しい勤務が先に並ぶ")
	# 上限を超えた既存履歴は、次の保存成功時に古い順で整理する。
	var limited := Fixtures.history_store()
	DirAccess.make_dir_recursive_absolute(limited.directory)
	for index in range(HistoryStore.MAX_ENTRIES + 1):
		var entry := saved.duplicate(true)
		entry.session_id = "%032x" % (index + 1)
		entry.completed_at += index
		write_json(limited.directory.path_join(entry.session_id + ".json"), entry)
	var damaged_path := limited.directory.path_join("d".repeat(32) + ".json")
	var unknown_path := limited.directory.path_join(unknown.session_id + ".json")
	var temporary_path := limited.directory.path_join("ignored.json.tmp")
	write_json(damaged_path, {})
	write_json(unknown_path, unknown)
	write_json(temporary_path, {})
	check(not limited.save_completed({}) and limited.list_entries().size() == 101, "保存失敗時は古い履歴を削除しない")
	var latest := saved.duplicate(true)
	latest.session_id = "e".repeat(32)
	latest.completed_at += 1000
	check(limited.save_completed(latest), "上限到達後も保存に成功")
	var retained := limited.list_entries()
	check(retained.size() == 100 and retained[0].session_id == latest.session_id, "最新100件を保持")
	check(not FileAccess.file_exists(limited.directory.path_join("%032x.json" % 1)) and not FileAccess.file_exists(limited.directory.path_join("%032x.json" % 2)), "最古の2件を削除")
	check(FileAccess.file_exists(damaged_path) and FileAccess.file_exists(unknown_path) and FileAccess.file_exists(temporary_path), "破損・未知版・一時ファイルを保持")
	check(limited.save_completed(latest) and limited.list_entries().size() == 100, "再保存で保持件数を減らさない")
	# 教材読込失敗の起動でも履歴への導線を残す。
	desk.queue_free()
	await process_frame
	desk = load("res://scenes/main.tscn").instantiate()
	desk.content_pack = "res://data/packs/missing.json"
	desk.history_store = reopened
	root.add_child(desk)
	await process_frame
	check(desk.start_screen.visible and desk.start_button.disabled, "教材エラー時は新規勤務だけ無効")
	desk.history_button.pressed.emit()
	desk._open_history_entry(saved.session_id)
	check(desk.summary_review.get_parsed_text().contains(saved.records[0].explanation), "教材エラー時も履歴を閲覧")
	desk.queue_free()
	await process_frame
	# 保存失敗時にも結果を表示し、同じIDで再試行する。
	desk = Fixtures.desk()
	desk.history_store = FailingStore.new()
	root.add_child(desk)
	await process_frame
	desk._start_shift()
	var basic_cases: Array[Dictionary] = desk.catalog.select_cases("very_beginner")
	desk.shift.start(basic_cases)
	for item in basic_cases:
		desk.shift.decide(item.ground_truth)
		desk.next.pressed.emit()
	check(desk.summary_overlay.visible and desk.summary_retry.visible, "保存失敗でも結果と再試行を表示")
	var retry_id: String = desk.completed_snapshot.session_id
	desk.history_store = Fixtures.history_store()
	desk.summary_retry.pressed.emit()
	check(not desk.summary_retry.visible and desk.history_store.load_entry(retry_id).session_id == retry_id, "同じ勤務IDで保存を再試行")
	desk.summary_restart.pressed.emit()
	check(desk.glossary_search.text.is_empty(), "勤務の再開始で検索語をリセット")
	check(desk.glossary_viewed.size() > 0 and desk.glossary_expanded.is_empty() and desk.completed_snapshot.is_empty(), "再開始で展開状態と前回結果をリセット")
	desk.queue_free()
	await process_frame
	print("Learning support tests: %d failures" % failures)
	quit(1 if failures else 0)
