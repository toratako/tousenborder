extends SceneTree
## 起動時と同じ検証を、任意の教材JSONへUIなしで実行する。
func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		paths.append("res://data/packs/learning.json")
	var failed := false
	for path in paths:
		var catalog := ContentCatalog.new()
		if catalog.load_pack(path):
			print("OK: %s (%d cases)" % [path, catalog.cases.size()])
		else:
			failed = true
			for error in catalog.errors:
				printerr(path + ": " + error)
	quit(1 if failed else 0)
