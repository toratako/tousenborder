extends SceneTree
## Runtime and authoring use the same loaders. --report emits one machine-readable line.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var report := "--report" in args
	var sources: Array[String] = []
	for arg in args:
		if arg != "--report": sources.append(arg)
	if sources.is_empty(): sources.append("res://data")
	var library := ProblemLibrary.new()
	var failed := false
	for path in sources:
		var absolute := ProjectSettings.globalize_path(path).simplify_path()
		var source_id := "builtin" if absolute == ProjectSettings.globalize_path("res://data") else "directory:" + absolute.sha256_text()
		var source := ContentSource.directory(path, source_id) if DirAccess.dir_exists_absolute(path) else ContentSource.open_file(path)
		if not library.add_source(source):
			failed = true
			for error in library.errors: printerr(path + ": " + error)
	if failed:
		quit(1)
		return
	if report:
		print("CONTENT_REPORT:" + JSON.stringify({"problems": library.cases, "packs": library.packs}, "", true))
	else:
		print("Content: OK (%d problems, %d packs)" % [library.cases.size(), library.packs.size()])
	quit()
