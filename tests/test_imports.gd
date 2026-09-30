extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
const Retry = preload("res://src/app/wrong_answer_retry.gd")


class FailingStore extends ContentImportStore:
	func save(_source: ContentSource) -> bool:
		error = "simulated write failure"
		return false


var failures := 0
var directory := Fixtures.temporary_directory("content")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)


func write_json(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()


func archive(path: String, files: Dictionary) -> void:
	var zip := ZIPPacker.new()
	assert(zip.open(path) == OK)
	for name in files:
		assert(zip.start_file(name) == OK)
		assert(zip.write_file(JSON.stringify(files[name]).to_utf8_buffer()) == OK)
		assert(zip.close_file() == OK)
	assert(zip.close() == OK)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var raw := Fixtures.raw("FIX-VISIBLE-FILE")
	raw.category = "custom"
	raw.category_label = "独自の分類"
	raw.erase("difficulty")
	raw.glossary = { "custom": { "label": "Custom", "description": "独立した用語" } }
	raw.initial.terms = ["custom"]
	var source_files := { "problems/example.json": raw }
	for path in source_files:
		write_json(directory.path_join("folder").path_join(path), source_files[path])
	var zip_path := directory.path_join("collection.zip")
	archive(zip_path, source_files)
	var source := ContentSource.open_file(zip_path)
	check(source.error.is_empty(), "通常のZIP: " + source.error)
	var library := ProblemLibrary.new()
	check(library.add_source(source), "PackなしZIP: " + str(library.errors))
	check(library.packs.is_empty() and library.cases.size() == 1, "問題のみを登録")
	var from_folder := ProblemLibrary.new()
	check(
		from_folder.add_source(ContentSource.directory(directory.path_join("folder"), source.id)),
		"ディレクトリ読込",
	)
	check(from_folder.cases == library.cases, "ZIPとディレクトリで同じ検証・モデル")
	var item: Dictionary = library.cases[0]
	check(item.difficulty == "unrated" and item.traits.method == "initial", "未評価と初期情報のみを分離")
	check(library.categories == [{ "id": "custom", "label": "独自の分類" }], "分類登録なしで独自問題を追加")
	var viewed := { LearningGlossary.key("initial_information", "initial"): true }
	check(
		LearningGlossary.visible_terms(item, { }, [], viewed)[0].description == "独立した用語",
		"共通辞書なしでも問題の用語を表示",
	)
	var store := ContentImportStore.new(directory.path_join("installed"))
	check(store.save(source) and store.save(source) and store.sources().size() == 1, "同一ZIPの追加は冪等")
	var reopened := ProblemLibrary.new()
	check(
		reopened.add_source(store.sources()[0]) and reopened.cases == library.cases,
		"再起動相当の読込で同じIDと内容",
	)
	var builtin := Fixtures.raw(raw.id)
	check(library.add_source(Fixtures.source([builtin])), "別の読込元の同一問題IDを登録")
	var snapshot := {
		"records": [
			{
				"id": raw.id,
				"correct": false,
				"source_id": source.id,
				"definition_hash": item.definition_hash,
			}
		]
	}
	check(Retry.plan(snapshot, library).cases[0].source_id == source.id, "同一IDでも外部教材の履歴を正しく再挑戦")
	check(Retry.plan(snapshot, Fixtures.library()).cases.is_empty(), "未読込の外部教材をbuiltinで代用しない")
	var changed := snapshot.duplicate(true)
	changed.records[0].definition_hash = "old-revision"
	check(Retry.plan(changed, library).changed == 1, "定義の変更を検出")
	var legacy := {
		"schema_version": 2,
		"pack": { "id": "learning" },
		"records": [{ "id": raw.id, "correct": false }],
	}
	check(Retry.plan(legacy, library).cases[0].source_id == "builtin", "旧履歴はbuiltinとして解決")
	var duplicate := Fixtures.source([raw], "duplicate")
	duplicate.files["problems/second.json"] = JSON.stringify(raw).to_utf8_buffer()
	var before := library.cases.duplicate(true)
	check(not library.add_source(duplicate) and library.cases == before, "同一読込元の重複IDを一括拒否")
	var newer := raw.duplicate(true)
	newer.schema_version = 99
	check(not ProblemLoader.load_value(newer).errors.is_empty(), "未知Schema版を拒否")
	for invalid_path in [
		"",
		"/absolute.json",
		"../outside.json",
		"dir/../x.json",
		"res://x.json",
		"dir\\x.json",
	]:
		check(not ContentSource.valid_path(invalid_path), "教材パスの境界")
	var invalid_file := directory.path_join("broken.zip")
	var file := FileAccess.open(invalid_file, FileAccess.WRITE)
	file.store_buffer(source.payload.slice(0, 10))
	file.close()
	check(not ContentSource.open_file(invalid_file).error.is_empty(), "途中で切れたZIPを拒否")
	var bounded := ContentSource.new()
	var oversized := PackedByteArray()
	oversized.resize(ContentSource.MAX_FILE_BYTES + 1)
	bounded._add("problems/large.json", oversized)
	check(not bounded.error.is_empty() and bounded.files.is_empty(), "ファイル上限を読込境界で適用")
	var facts := [{ "id": "digest", "value": "{{input}}" }]
	check(
		Information.render("{{fact:digest}} / {{input}}", facts, { "value": "selected" })
		== "{{input}} / selected",
		"置換した文字列を再評価しない",
	)
	check(
		not Information.validate_template("{{fact:missing}}", facts, true).is_empty(),
		"欠けた表示参照を拒否",
	)
	# A pack owns only sequencing and may repeat a standalone problem.
	source_files["packs/story/pack.json"] = {
		"schema_version": 3,
		"id": "story",
		"title": "物語",
		"problems": [raw.id, raw.id],
	}
	var story_path := directory.path_join("story.zip")
	archive(story_path, source_files)
	var story := ContentSource.open_file(story_path)
	check(library.add_source(story), "PackをZIPで読込: " + str(library.errors))
	var pack: Dictionary = library.packs[0]
	var ordered := library.pack_cases(pack.key)
	check(ordered.map(func(c): return c.id) == [raw.id, raw.id], "Packの順序と同じ問題の再使用")
	ordered[0].title = "セッション側の変更"
	check(
		ordered[1].title == raw.title and library.cases.filter(
			func(c):
				return c.source_id == story.id,
		)[0].title == raw.title,
		"出題用コピーの変更を問題本体や次の出題に混ぜない",
	)
	var missing := ContentSource.new()
	missing.id = "missing-problem"
	missing.files = story.files.duplicate(true)
	var invalid_pack: Dictionary = source_files["packs/story/pack.json"].duplicate(true)
	invalid_pack.problems = ["unknown-problem"]
	missing.files["packs/story/pack.json"] = JSON.stringify(invalid_pack).to_utf8_buffer()
	check(not library.add_source(missing), "存在しない問題を参照するPackを拒否")
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	desk.start_screen.tool_guide_button.pressed.emit()
	var cached_guide: Control = desk.tool_guide
	desk.tool_guide.close_button.pressed.emit()
	var working_store: ContentImportStore = desk.import_store
	desk.import_store = FailingStore.new(directory.path_join("failed"))
	var before_import: int = desk.library.cases.size()
	desk._import_content(story_path)
	check(
		desk.library.cases.size() == before_import and desk.library.packs.is_empty(),
		"保存失敗ならUIの登録も変更しない",
	)
	check(desk.tool_guide == cached_guide, "保存失敗なら既存のツールガイドも保持")
	desk.import_store = working_store
	desk._import_content(story_path)
	check(
		desk.library.packs.size() == 1 and desk.import_store.sources().size() == 1,
		"UIから検証・保存・登録",
	)
	await process_frame
	check(not is_instance_valid(cached_guide) and desk.tool_guide == null, "教材追加で古いガイドを破棄")
	desk.start_screen.tool_guide_button.pressed.emit()
	check(desk.tool_guide.tools == desk.library.guide_tools(), "追加後の教材からガイドを再構築")
	desk.tool_guide.close_button.pressed.emit()
	desk.start_screen.pack_select.select(1)
	desk._start_shift()
	check(desk.shift.current().id == raw.id, "Packの最初の問題を出題")
	desk.shift.decide(raw.ground_truth)
	desk.audit_overlay.next_button.pressed.emit()
	check(
		desk.shift.current().id == raw.id and desk.shift.index == 1 and not desk.shift.judged,
		"同じ問題IDを次の問題として再出題",
	)
	desk.shift.decide(raw.ground_truth)
	desk.audit_overlay.next_button.pressed.emit()
	check(
		desk.completed_snapshot.records.size() == 2
		and HistoryStore.validate(desk.completed_snapshot).is_empty(),
		"重複出題の履歴を保存",
	)
	var saved: Dictionary = desk.completed_snapshot.duplicate(true)
	var version_two := saved.duplicate(true)
	version_two.schema_version = 2
	for record in version_two.records:
		for key in ["source_id", "definition_hash", "category_label", "method"]:
			record.erase(key)
	check(HistoryStore.validate(version_two).is_empty(), "読込元情報のないversion 2履歴も読める")
	var import_store: ContentImportStore = desk.import_store
	desk.queue_free()
	await process_frame
	desk = Fixtures.desk()
	desk.import_store = import_store
	root.add_child(desk)
	await process_frame
	check(
		desk.library.packs.size() == 1 and desk.library.cases.size() == Fixtures.count() + 1,
		"次の起動でも追加した教材を出題可能",
	)
	desk.library.cases.clear()
	desk._display_summary(saved, true)
	desk.summary_screen.review.meta_clicked.emit(0)
	check(desk.summary_screen.review.get_parsed_text().contains(raw.explanation), "教材がなくても履歴を表示")
	desk.queue_free()
	await process_frame
	print("Content imports and packs: %d failures" % failures)
	quit(1 if failures else 0)
