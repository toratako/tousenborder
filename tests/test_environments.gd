extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
## 出題フィルタに関係なく共通問題はLinuxで調査し、資料の所有案件を照合する。
func _initialize() -> void:
	var library := Fixtures.library()
	assert(library.load_builtin(), str(library.errors))
	for platform in ["", "common", "windows", "linux"]:
		var item: Dictionary = library.select_cases("", "web", platform, "tools")[0]
		var tools := library.tools_for(item)
		var windows: Dictionary = tools.filter(func(t): return t.id == "resolve_dnsname")[0]
		var linux: Dictionary = tools.filter(func(t): return t.id == "dig")[0]
		var common: Dictionary = tools.filter(func(t): return t.id == "nslookup")[0]
		assert(item.investigation_environment == "linux")
		assert(not ToolRunner.supports_target(windows, item))
		assert(ToolRunner.supports_target(linux, item))
		assert(ToolRunner.supports_target(common, item))
		var other := item.duplicate(true)
		other.id = "OTHER"
		other.key = "OTHER"
		assert(not ToolRunner.new().run(common, other).ok)
	assert(library.cases.all(func(c): return c.platform in ["windows", "linux", "common"]))
	print("Environment and resource ownership tests passed")
	quit()
