class_name ContentCatalog
extends RefCounted
## 勤務開始前に教材を検証する。案件データをコードとして実行しない。

var cases: Array[Dictionary] = []
var tools: Array[Dictionary] = []
var rules: Array = []
var errors: PackedStringArray = []
var time_limit_seconds := 0

func load_pack(path: String = "res://data/intro.json") -> bool:
	cases.clear()
	tools.clear()
	rules.clear()
	errors.clear()
	time_limit_seconds = 0
	var pack = _read(path)
	if not pack is Dictionary:
		return false
	var limit = pack.get("time_limit_seconds", 0)
	if not (limit is int or limit is float) or not is_finite(float(limit)) or limit < 0 or limit > 86400 or float(limit) != floor(float(limit)):
		errors.append("time_limit_seconds は0〜86400の整数（秒）で指定してください。0は時間制限なしです。")
		return false
	time_limit_seconds = int(limit)
	if not pack.get("rules") is Array or not pack.get("cases") is Array or not pack.get("tools") is Array:
		errors.append("教材には rules・cases・tools の配列が必要です。")
		return false
	rules = pack.rules
	for rule in rules:
		if not rule is String:
			errors.append("規則は文字列で指定してください。")
	var ids: Dictionary = {}
	for tool_path in pack.tools:
		if not tool_path is String:
			errors.append("ツールのパスは文字列で指定してください。")
			continue
		var tool = _read(tool_path)
		if not _strings(tool, ["id", "label", "description", "provider"]):
			errors.append("ツールの定義が不正です: %s" % tool_path)
			continue
		if not tool.get("target_types") is Array or tool.target_types.is_empty():
			errors.append("ツールに target_types が必要です: %s" % tool_path)
			continue
		for target_type in tool.target_types:
			if not target_type is String or target_type.is_empty():
				errors.append("target_types は空でない文字列で指定してください: %s" % tool_path)
		if ids.has(tool.id):
			errors.append("ツールIDが重複しています: %s" % tool.id)
		ids[tool.id] = true
		tools.append(tool)
	ids.clear()
	for case_path in pack.cases:
		if not case_path is String:
			errors.append("案件のパスは文字列で指定してください。")
			continue
		var item = _read(case_path)
		if not _strings(item, ["id", "type", "title", "request", "expected", "explanation"]):
			errors.append("案件の定義が不正です: %s" % case_path)
			continue
		if not item.expected in ["approve", "deny"] or not item.get("fields") is Dictionary or not item.get("evidence") is Dictionary:
			errors.append("案件には fields・evidence と有効な expected の判定値が必要です: %s" % case_path)
			continue
		if ids.has(item.id):
			errors.append("案件IDが重複しています: %s" % item.id)
		ids[item.id] = true
		for field in item.fields.values():
			if not field is String:
				errors.append("案件の項目値は文字列で指定してください: %s" % item.id)
		for key in item.evidence:
			if not item.evidence[key] is String:
				errors.append("調査結果は文字列で指定してください: %s" % item.id)
			var matching := tools.filter(func(t): return t.id == key and item.type in t.target_types)
			if matching.is_empty():
				errors.append("調査結果のツールが未登録、または対象に非対応です: %s / %s" % [item.id, key])
		cases.append(item)
	if cases.is_empty():
		errors.append("教材に案件がありません。")
	return errors.is_empty()

func _strings(value: Variant, keys: Array) -> bool:
	if not value is Dictionary:
		return false
	for key in keys:
		if not value.get(key) is String or value[key].is_empty():
			return false
	return true

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("教材ファイルが見つかりません: %s" % path)
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s:%d行目: JSONの書式が不正です。" % [path, parser.get_error_line()])
		return null
	return parser.data
