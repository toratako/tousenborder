class_name ContentCatalog
extends RefCounted
## Schemaと問題間の整合性を検証し、検証が完了した教材だけを公開する。

const DEFAULT_PACK := "res://data/packs/learning.json"
const DIFFICULTIES := {"very_beginner": "超初級", "beginner": "初級", "intermediate": "中級", "advanced": "上級"}
const PLATFORMS := {"windows": "Windows", "linux": "Linux", "common": "環境共通"}
const RESOURCE_GROUPS := {
	"tools": {"id": "tools", "label": "Tools", "kind": "tools"},
	"references": {"id": "references", "label": "References", "kind": "references"},
	"external_references": {"id": "external_references", "label": "External References", "kind": "external_references"}
}

var cases: Array[Dictionary] = []
var rules: Array[Dictionary] = []
var errors: PackedStringArray = []
var title := ""
var pack_id := ""
var glossary_terms: Dictionary = {}
var actions: Array[Dictionary] = default_actions()
var feedback: Dictionary = {}
var categories: Array[Dictionary] = []
var platforms: Dictionary = {}
var difficulties: Dictionary = {}
var resource_groups: Dictionary = {}

static func default_actions() -> Array[Dictionary]:
	return [{"id": "allow", "label": "ALLOW", "color": "8ba879"},
		{"id": "block", "label": "BLOCK", "color": "bc6452"}]

func tools_for(item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group in resource_groups:
		var source: Dictionary = item if group in RESOURCE_GROUPS else item.get("resources", {})
		result.append_array(source.get(group, []))
	return result

func platform_label(id: String) -> String:
	return platforms.get(id, {}).get("label", id)

func select_cases(level: String = "", category: String = "", platform: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in cases:
		if not level.is_empty() and item.level != level: continue
		if not category.is_empty() and item.category != category: continue
		if not platform.is_empty() and item.platform not in [platform, "common"]: continue
		var selected: Dictionary = item.duplicate(true)
		selected.investigation_environment = ToolRunner.investigation_environment(item)
		result.append(selected)
	return result

func guide_tools() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var known := {}
	for item in cases:
		for tool in tools_for(item):
			if tool.resource_kind == "references": continue
			var key: Array = [tool.group, tool.id, tool.label]
			if not known.has(key):
				var entry := {"categories": [], "example_platforms": []}
				# 結果・正解・出力情報はガイドへ渡さない。
				for field in ["id", "label", "description", "group", "resource_kind", "environments", "accepted_information_types", "input_hint", "platform_note"]:
					if tool.has(field): entry[field] = tool[field]
				known[key] = entry
				result.append(entry)
			var entry: Dictionary = known[key]
			if item.category not in entry.categories: entry.categories.append(item.category)
			if item.platform not in entry.example_platforms: entry.example_platforms.append(item.platform)
	return result

func load_pack(path: String = DEFAULT_PACK) -> bool:
	_reset()
	var pack: Variant = _read(path)
	if not errors.is_empty(): return false
	var schema_errors := ContentSchema.validate(pack, ContentSchema.PACK)
	for error in schema_errors: errors.append(path + ": " + error)
	if not errors.is_empty(): return false
	if pack.has("glossary_path"):
		var glossary: Variant = _read(pack.glossary_path)
		if not errors.is_empty(): return false
		for error in ContentSchema.validate(glossary, ContentSchema.GLOSSARY):
			errors.append(pack.glossary_path + ": " + error)
		if not errors.is_empty(): return false
		for id in glossary.terms:
			if id.strip_edges().is_empty(): errors.append("用語IDは空にできません。")
		if not errors.is_empty(): return false
		glossary_terms = glossary.terms.duplicate(true)
	for key in ["categories", "rules", "resource_groups"]:
		var ids := {}
		for entry in pack.get(key, []):
			if ids.has(entry.id): errors.append(key + " のIDが重複しています: " + entry.id)
			ids[entry.id] = true
	for group in pack.get("resource_groups", []):
		if group.id == "initial_information" or (group.id in RESOURCE_GROUPS and group.kind != group.id):
			errors.append("予約済み資料グループのkindは変更できません: " + group.id)
		resource_groups[group.id] = group.duplicate(true)
	if not errors.is_empty(): return false
	title = pack.title
	pack_id = pack.id
	feedback = pack.get("feedback", {}).duplicate(true)
	categories.assign(pack.categories)
	for rule in pack.rules:
		var info: Dictionary = rule.duplicate(true)
		info.merge({"category": "rule", "draggable": false, "tool_input": false})
		rules.append(info)
	var problem_schema: Variant = ContentSchema.read_schema(ContentSchema.PROBLEM)
	var pending: Array[Dictionary] = []
	var ids := {}
	for problem_path in pack.problems:
		var item: Variant = _read(problem_path)
		schema_errors = ContentSchema.check(item, problem_schema)
		if not schema_errors.is_empty():
			for error in schema_errors: errors.append(problem_path + ": " + error)
			continue
		if ids.has(item.id): errors.append("問題IDが重複しています: " + item.id)
		ids[item.id] = true
		var error := ProblemData.normalize(item, self, problem_schema)
		if not error.is_empty():
			errors.append(problem_path + ": " + error)
		else:
			pending.append(item)
	if not errors.is_empty(): return false
	cases = pending
	return true

func _reset() -> void:
	cases.clear()
	rules.clear()
	errors.clear()
	title = ""
	pack_id = ""
	glossary_terms.clear()
	feedback.clear()
	categories.clear()
	actions = default_actions()
	resource_groups = RESOURCE_GROUPS.duplicate(true)
	platforms = _definitions(PLATFORMS)
	difficulties = _definitions(DIFFICULTIES)

static func _definitions(labels: Dictionary) -> Dictionary:
	var result := {}
	for id in labels: result[id] = {"id": id, "label": labels[id]}
	return result

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("教材ファイルがありません: " + path)
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data
