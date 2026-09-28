class_name ProblemLibrary
extends RefCounted
## Indexes validated problems. No problem depends on the index or on a pack.
const DEFAULT_ROOT := "res://data"
var cases: Array[Dictionary] = []
var packs: Array[Dictionary] = []
var categories: Array[Dictionary] = []
var platforms: Dictionary = { }
var difficulties: Dictionary = { }
var methods: Dictionary = { }
var errors: PackedStringArray = []
var _sources: Dictionary = { }


func load_builtin(root := DEFAULT_ROOT) -> bool:
	cases.clear()
	packs.clear()
	_sources.clear()
	_reindex()
	return add_source(ContentSource.directory(root))


func prepare_source(source: ContentSource) -> Dictionary:
	var failures: PackedStringArray = []
	if not source.error.is_empty():
		return { "errors": PackedStringArray([source.error]) }
	var problems := { }
	var loaded_packs: Array[Dictionary] = []
	var paths: Array = source.files.keys()
	paths.sort()
	for path in paths:
		if not path.begins_with("problems/"):
			continue
		var loaded := ProblemLoader.parse(
			source.files[path],
			{ "source_id": source.id, "path": path },
		)
		if not loaded.errors.is_empty():
			for error in loaded.errors:
				failures.append(path + ": " + error)
			continue
		var item: Dictionary = loaded.problem
		if problems.has(item.id):
			failures.append(path + ": 問題IDが重複しています: " + item.id)
		problems[item.id] = item
	if problems.is_empty():
		failures.append("problems/ に出題できる問題がありません。")
	var pack_ids := { }
	for path in paths:
		if not path.begins_with("packs/") or not path.ends_with("/pack.json"):
			continue
		var loaded := PackLoader.load_pack(source, path, problems)
		failures.append_array(loaded.errors)
		if loaded.errors.is_empty():
			if pack_ids.has(loaded.pack.id):
				failures.append(path + ": Pack IDが重複しています。")
			pack_ids[loaded.pack.id] = true
			loaded_packs.append(loaded.pack)
	return {
		"errors": failures,
		"source_id": source.id,
		"problems": problems,
		"packs": loaded_packs,
	}


func add_source(source: ContentSource) -> bool:
	var prepared := prepare_source(source)
	errors = prepared.errors
	if not errors.is_empty():
		return false
	commit_source(prepared)
	return true


func commit_source(prepared: Dictionary) -> void:
	assert(prepared.errors.is_empty())
	_sources[prepared.source_id] = prepared
	cases.clear()
	packs.clear()
	for entry in _sources.values():
		cases.append_array(entry.problems.values())
		packs.append_array(entry.packs)
	errors.clear()
	_reindex()


func _reindex() -> void:
	categories.clear()
	platforms.clear()
	difficulties.clear()
	methods.clear()
	var category_ids := { }
	for item in cases:
		if not category_ids.has(item.category):
			categories.append({ "id": item.category, "label": ContentLabels.category(item) })
			category_ids[item.category] = true
		platforms[item.platform] = {
			"id": item.platform,
			"label": ContentLabels.PLATFORMS[item.platform],
		}
		difficulties[item.difficulty] = {
			"id": item.difficulty,
			"label": ContentLabels.DIFFICULTIES[item.difficulty],
		}
		methods[item.traits.method] = {
			"id": item.traits.method,
			"label": ContentLabels.METHODS[item.traits.method],
		}


static func tools_for(item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(item.resources)
	return result


static func groups_for(resources: Array) -> Dictionary:
	var groups := { }
	for kind in ContentLabels.KINDS:
		for resource in resources:
			if resource.kind == kind:
				groups[resource.group] = {
					"id": resource.group,
					"label": resource.group_label,
					"kind": kind,
				}
	return groups


func platform_label(id: String) -> String:
	return ContentLabels.PLATFORMS.get(id, id)


func select_cases(
	difficulty := "",
	category := "",
	platform := "",
	method := "",
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in cases:
		if not difficulty.is_empty() and item.difficulty != difficulty:
			continue
		if not category.is_empty() and item.category != category:
			continue
		if not platform.is_empty() and item.platform not in [platform, "common"]:
			continue
		if not method.is_empty() and item.traits.method != method:
			continue
		var selected: Dictionary = item.duplicate(true)
		selected.investigation_environment = ProblemContext.investigation_environment(item)
		result.append(selected)
	return result


func pack_cases(key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pack in packs:
		if pack.key != key:
			continue
		for chapter in pack.chapters:
			for index in chapter.problems.size():
				var item: Dictionary = _sources[pack.source_id] \
						.problems[chapter.problems[index]] \
						.duplicate(true)
				if index == 0:
					item.chapter = {
						"id": pack.key + "/" + chapter.id,
						"title": chapter.title,
						"intro": chapter.get("intro", ""),
					}
				result.append(item)
	return result


func guide_tools() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var known := { }
	for item in cases:
		for tool in item.resources:
			if tool.kind == "references":
				continue
			var entry := { }
			for field in [
				"label",
				"description",
				"kind",
				"environments",
				"accepted_information_types",
				"input_hint",
				"platform_note",
			]:
				if tool.has(field):
					entry[field] = tool[field]
			# Keep distinct input modes and descriptions; order must not discard a variant.
			var key := JSON.stringify(entry, "", true)
			if not known.has(key):
				entry.id = tool.id
				entry.categories = []
				known[key] = entry
				result.append(entry)
			if item.category not in known[key].categories:
				known[key].categories.append(item.category)
	return result
