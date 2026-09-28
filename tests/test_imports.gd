extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
const Retry = preload("res://scripts/core/wrong_answer_retry.gd")
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
	raw.glossary = {"custom": {"label": "Custom", "description": "独立した用語"}}
	raw.initial.terms = ["custom"]
	var source_files := {"problems/example.json": raw}
	for path in source_files: write_json(directory.path_join("folder").path_join(path), source_files[path])
	var zip_path := directory.path_join("collection.zip")
	archive(zip_path, source_files)
	var source := ContentSource.open_file(zip_path)
	check(source.error.is_empty(), "通常のZIP: " + source.error)
	var library := ProblemLibrary.new()
	check(library.add_source(source), "PackなしZIP: " + str(library.errors))
	check(library.packs.is_empty() and library.cases.size() == 1, "問題のみを登録")
	var from_folder := ProblemLibrary.new()
	check(from_folder.add_source(ContentSource.directory(directory.path_join("folder"), source.id)), "ディレクトリ読込")
	check(from_folder.cases == library.cases, "ZIPとディレクトリで同じ検証・モデル")
	var item: Dictionary = library.cases[0]
	check(item.difficulty == "unrated" and item.traits.method == "initial", "未評価と初期情報のみを分離")
	check(library.categories == [{"id": "custom", "label": "独自の分類"}], "分類登録なしで独自問題を追加")
	var viewed := {LearningGlossary.key("initial_information", "initial"): true}
	check(LearningGlossary.visible_terms(item, {}, [], viewed)[0].description == "独立した用語", "共通辞書なしでも問題の用語を表示")
	var store := ContentImportStore.new(directory.path_join("installed"))
	check(store.save(source) and store.save(source) and store.sources().size() == 1, "同一ZIPの追加は冪等")
	var reopened := ProblemLibrary.new()
	check(reopened.add_source(store.sources()[0]) and reopened.cases == library.cases, "再起動相当の読込で同じIDと内容")
	var builtin := Fixtures.raw(raw.id)
	check(library.add_source(Fixtures.source([builtin])), "別の読込元の同一問題IDを登録")
	var snapshot := {"records": [{"id": raw.id, "correct": false, "source_id": source.id, "definition_hash": item.definition_hash}]}
	check(Retry.plan(snapshot, library).cases[0].source_id == source.id, "同一IDでも外部教材の履歴を正しく再挑戦")
	check(Retry.plan(snapshot, Fixtures.library()).cases.is_empty(), "未読込の外部教材をbuiltinで代用しない")
	var changed := snapshot.duplicate(true)
	changed.records[0].definition_hash = "old-revision"
	check(Retry.plan(changed, library).changed == 1, "定義の変更を検出")
	var legacy := {"schema_version": 2, "pack": {"id": "learning"}, "records": [{"id": raw.id, "correct": false}]}
	check(Retry.plan(legacy, library).cases[0].source_id == "builtin", "旧履歴はbuiltinとして解決")
	var duplicate := Fixtures.source([raw], "duplicate")
	duplicate.files["problems/second.json"] = JSON.stringify(raw).to_utf8_buffer()
	var before := library.cases.duplicate(true)
	check(not library.add_source(duplicate) and library.cases == before, "同一読込元の重複IDを一括拒否")
	var newer := raw.duplicate(true)
	newer.schema_version = 99
	check(not ProblemLoader.load_value(newer).errors.is_empty(), "未知Schema版を拒否")
	for invalid_path in ["", "/absolute.json", "../outside.json", "dir/../x.json", "res://x.json", "dir\\x.json"]:
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
	var facts := [{"id": "digest", "value": "{{input}}"}]
	check(Information.render("{{fact:digest}} / {{input}}", facts, {"value": "selected"}) == "{{input}} / selected", "置換した文字列を再評価しない")
	check(not Information.validate_template("{{fact:missing}}", facts, true).is_empty(), "欠けた表示参照を拒否")
	# A pack owns only sequencing. Multiple chapter files can repeat a standalone problem.
	source_files["packs/story/pack.json"] = {"schema_version": 2, "id": "story", "title": "物語", "chapters": ["chapters/01.json", "chapters/02.json"]}
	source_files["packs/story/chapters/01.json"] = {"schema_version": 1, "id": "first", "title": "一章", "intro": "朝の審査", "problems": [raw.id]}
	source_files["packs/story/chapters/02.json"] = {"schema_version": 1, "id": "second", "title": "二章", "intro": "夕方の審査", "problems": [raw.id]}
	var story_path := directory.path_join("story.zip")
	archive(story_path, source_files)
	var story := ContentSource.open_file(story_path)
	check(library.add_source(story), "章を複数JSONで読込: " + str(library.errors))
	var pack: Dictionary = library.packs[0]
	var ordered := library.pack_cases(pack.key)
	check(ordered.size() == 2 and ordered[0].chapter.id != ordered[1].chapter.id, "章の順序と同じ問題の再使用")
	check(not library.cases.filter(func(c): return c.source_id == story.id)[0].has("chapter"), "問題本体に章情報を混ぜない")
	var missing := ContentSource.new()
	missing.id = "missing-chapter"
	missing.files = story.files.duplicate(true)
	missing.files.erase("packs/story/chapters/02.json")
	check(not library.add_source(missing), "欠けた章を含むPackを拒否")
	var desk = Fixtures.desk()
	root.add_child(desk)
	await process_frame
	var working_store: ContentImportStore = desk.import_store
	desk.import_store = FailingStore.new(directory.path_join("failed"))
	var before_import: int = desk.library.cases.size()
	desk._import_content(story_path)
	check(desk.library.cases.size() == before_import and desk.library.packs.is_empty(), "保存失敗ならUIの登録も変更しない")
	desk.import_store = working_store
	desk._import_content(story_path)
	check(desk.library.packs.size() == 1 and desk.import_store.sources().size() == 1, "UIから検証・保存・登録")
	desk.pack_select.select(1)
	desk._start_shift()
	check(desk.chapter_overlay.visible and desk.chapter_continue.has_focus(), "最初の章の導入を表示")
	desk._toggle_menu()
	check(not desk.pause_menu.visible, "章の導入中にメニューを重ねない")
	var elapsed: float = desk.shift.elapsed_seconds
	desk._process(5)
	check(desk.shift.elapsed_seconds == elapsed and not desk._can_stamp(desk.get_stamp("allow").payload()), "章の導入中は時計・判定を停止")
	desk.chapter_continue.pressed.emit()
	check(not desk.chapter_overlay.visible, "導入から問題へ")
	desk.shift.decide(raw.ground_truth)
	desk.next.pressed.emit()
	check(desk.chapter_overlay.visible and desk.chapter_body.get_parsed_text().contains("夕方") and not desk.shift.judged, "同じ問題IDでも次の章を再表示: %s / %s / %s / %s" % [desk.chapter_overlay.visible, desk.chapter_body.get_parsed_text(), desk.shift.judged, desk.shift.index])
	desk.chapter_continue.pressed.emit()
	desk.shift.decide(raw.ground_truth)
	desk.next.pressed.emit()
	check(desk.completed_snapshot.records.size() == 2 and HistoryStore.validate(desk.completed_snapshot).is_empty(), "複数章の履歴を保存")
	var saved: Dictionary = desk.completed_snapshot.duplicate(true)
	var version_two := saved.duplicate(true)
	version_two.schema_version = 2
	for record in version_two.records:
		for key in ["source_id", "definition_hash", "category_label", "method"]: record.erase(key)
	check(HistoryStore.validate(version_two).is_empty(), "読込元情報のないversion 2履歴も読める")
	var import_store: ContentImportStore = desk.import_store
	desk.queue_free()
	await process_frame
	desk = Fixtures.desk()
	desk.import_store = import_store
	root.add_child(desk)
	await process_frame
	check(desk.library.packs.size() == 1 and desk.library.cases.size() == Fixtures.count() + 1, "次の起動でも追加した教材を出題可能")
	desk.library.cases.clear()
	desk._display_summary(saved, true)
	check(desk.summary_review.get_parsed_text().contains(raw.explanation), "教材がなくても履歴を表示")
	desk.queue_free()
	await process_frame
	print("Content imports and chapters: %d failures" % failures)
	quit(1 if failures else 0)
