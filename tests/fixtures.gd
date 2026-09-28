extends RefCounted
## Stable standalone fixtures; storage and UI tests share the real loader.
const DATA = "res://tests/fixtures/content.json"


static func raw(id: String) -> Dictionary:
	for item in JSON.parse_string(FileAccess.get_file_as_string(DATA)).problems:
		if item.id == id:
			return item
	assert(false, "Unknown fixture: " + id)
	return { }


static func resources(item: Dictionary, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(
		item.resources.filter(
			func(resource):
				return resource.kind == kind,
		)
	)
	return result


static func resource(item: Dictionary, id: String) -> Dictionary:
	for entry in item.resources:
		if entry.id == id:
			return entry
	assert(false, "Unknown resource: " + id)
	return { }


static func source(items: Array, source_id := "builtin") -> ContentSource:
	var result := ContentSource.new()
	result.id = source_id
	for item in items:
		result.files["problems/" + item.id + ".json"] = JSON.stringify(item).to_utf8_buffer()
	return result


static func loaded(item: Dictionary, source_id := "builtin") -> Dictionary:
	var result := ProblemLoader.load_value(item, { "source_id": source_id })
	assert(result.errors.is_empty(), str(result.errors))
	return result.problem


class FixtureLibrary extends ProblemLibrary:
	func load_builtin(_root := DEFAULT_ROOT) -> bool:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		var fixture_source := ContentSource.new()
		fixture_source.id = "builtin"
		for item in data.problems:
			fixture_source.files["problems/" + item.id + ".json"] = JSON \
					.stringify(item) \
					.to_utf8_buffer()
		if not add_source(fixture_source):
			return false
		var order: Array = data.problems.map(
			func(item):
				return item.id,
		)
		cases.sort_custom(
			func(a, b):
				return order.find(a.id) < order.find(b.id),
		)
		return true


static func library() -> ProblemLibrary:
	return FixtureLibrary.new()


static func desk():
	var instance = load("res://scenes/main.tscn").instantiate()
	instance.library = library()
	instance.history_store = history_store()
	instance.import_store = ContentImportStore.new(temporary_directory("imports"))
	return instance


static func temporary_directory(kind: String) -> String:
	return "res://build/test-" + kind + "/" + Crypto.new().generate_random_bytes(16).hex_encode()


static func history_store() -> HistoryStore:
	return HistoryStore.new(temporary_directory("history"))


static func count() -> int:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA)).problems.size()
