extends RefCounted
## 教材の差替えに左右されないUI・入力契約の固定データ。通常の出題には登録しない。

const DATA = "res://tests/fixtures/content.json"

static func pack() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA)).pack

static func raw(id: String) -> Dictionary:
	for item in JSON.parse_string(FileAccess.get_file_as_string(DATA)).problems:
		if item.id == id:
			return item
	assert(false, "Unknown fixture: " + id)
	return {}

class FixtureCatalog extends ContentCatalog:
	func _read(path: String) -> Variant:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if path == DEFAULT_PACK:
			return data.pack
		for item in data.problems:
			if path == "res://data/problems/" + item.id + ".json":
				return item
		return super._read(path)

static func catalog() -> ContentCatalog:
	return FixtureCatalog.new()

static func desk():
	var instance = load("res://scenes/main.tscn").instantiate()
	instance.catalog = catalog()
	return instance
