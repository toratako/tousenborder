class_name HistoryStore
extends RefCounted
## 一勤務一ファイル。教材の現行データや画面には依存しない。
const MAX_ENTRIES := 100
var directory: String
var error := ""
var warnings: PackedStringArray = []

func _init(path: String = "user://history") -> void:
	directory = path

static func snapshot(shift: InspectionShift, pack: Dictionary, selection: Dictionary, feedback: Dictionary, actions: Array[Dictionary]) -> Dictionary:
	if not shift.finished() or shift.records.is_empty(): return {}
	var labels := {}
	for action in actions: labels[action.id] = action.label
	return {"schema_version": 2, "session_id": shift.session_id, "started_at": shift.started_at,
		"completed_at": Time.get_unix_time_from_system(), "pack": pack.duplicate(true),
		"selection": selection.duplicate(true), "elapsed_seconds": shift.elapsed_seconds,
		"stats": {"answered": shift.records.size(), "correct": shift.score(), "unsafe": shift.unsafe_investigations()},
		"feedback": {"show_reason": feedback.get("show_reason", true), "show_expected": feedback.get("show_expected", true)},
		"action_labels": labels, "records": shift.records.duplicate(true)}

static func valid_id(id: String) -> bool:
	if id.length() != 32: return false
	for character in id:
		if character not in "0123456789abcdef": return false
	return true

static func validate(data: Variant) -> String:
	var errors := ContentSchema.validate(data, ContentSchema.HISTORY)
	if not errors.is_empty(): return "; ".join(errors)
	var correct := 0
	var unsafe := 0
	for record in data.records:
		if record.correct != (record.verdict == record.ground_truth): return "判定の整合性エラー"
		if record.correct: correct += 1
		for observation in record.observations:
			if (observation.has("correct_usage") or observation.get("skipped", false)) and not observation.has("reason"):
				return "調査理由がありません"
			if observation.ok and not observation.get("correct_usage", true): unsafe += 1
	if data.stats.answered != data.records.size() or data.stats.correct != correct or data.stats.unsafe != unsafe:
		return "勤務集計の整合性エラー"
	return ""

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "履歴を読み込めません: " + str(FileAccess.get_open_error())
		return {}
	var parser := JSON.new()
	var status := parser.parse(file.get_as_text())
	file.close()
	if status != OK:
		error = "履歴JSONが壊れています。"
		return {}
	error = validate(parser.data)
	return parser.data if error.is_empty() else {}

func load_entry(id: String) -> Dictionary:
	error = ""
	if not valid_id(id):
		error = "履歴IDが不正です。"
		return {}
	var data := _read(directory.path_join(id + ".json"))
	if not data.is_empty() and data.session_id != id:
		error = "履歴IDが一致しません。"
		return {}
	return data

func save_completed(data: Dictionary) -> bool:
	error = validate(data)
	if not error.is_empty(): return false
	var path := directory.path_join(data.session_id + ".json")
	if FileAccess.file_exists(path):
		var existing := load_entry(data.session_id)
		if existing.is_empty(): return false
		if not ContentSchema._equal(existing, data):
			error = "同じIDに異なる勤務結果があります。"
			return false
		_prune_entries()
		return true
	var status := DirAccess.make_dir_recursive_absolute(directory)
	if status != OK:
		error = "履歴の保存先を作成できません: " + str(status)
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error = "履歴を書き込めません: " + str(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	status = file.get_error()
	file.close()
	if status != OK:
		error = "履歴の書き込みに失敗しました: " + str(status)
		return false
	if _read(temporary).is_empty(): return false
	status = DirAccess.rename_absolute(temporary, path)
	if status != OK:
		error = "履歴を確定できません: " + str(status)
		return false
	_prune_entries()
	return true

func _prune_entries() -> void:
	# 保存確定後だけ整理する。破損・未知版・一時ファイルは削除しない。
	var entries := list_entries()
	for index in range(MAX_ENTRIES, entries.size()):
		var path := directory.path_join(entries[index].session_id + ".json")
		var status := DirAccess.remove_absolute(path)
		if status != OK:
			warnings.append("古い履歴を削除できません: " + str(status))
	# 整理の失敗と、新規履歴の保存成功は分ける。
	error = ""

func list_entries() -> Array[Dictionary]:
	error = ""
	warnings.clear()
	var entries: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(directory): return entries
	var dir := DirAccess.open(directory)
	if dir == null:
		warnings.append("履歴フォルダを開けません。")
		return entries
	for filename in dir.get_files():
		if not filename.ends_with(".json") or not valid_id(filename.get_basename()): continue
		var data := load_entry(filename.get_basename())
		if data.is_empty():
			warnings.append(filename + ": " + error)
		else:
			entries.append(data)
	entries.sort_custom(func(a, b): return a.completed_at > b.completed_at if a.completed_at != b.completed_at else a.session_id > b.session_id)
	return entries

static func date_label(timestamp: float) -> String:
	var local_time := timestamp + int(Time.get_time_zone_from_system().bias) * 60
	return Time.get_datetime_string_from_unix_time(int(local_time), true)
