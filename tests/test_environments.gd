extends SceneTree
## 出題フィルタに関係なく共通問題はLinuxで調査し、資料の所有案件を照合する。
func _initialize() -> void:
	var catalog := ContentCatalog.new()
	assert(catalog.load_pack(), str(catalog.errors))
	for platform in ["", "common", "windows", "linux"]:
		var item: Dictionary = catalog.select_cases("beginner", "web", platform)[0]
		var tools := catalog.tools_for(item)
		var windows: Dictionary = tools.filter(func(t): return t.id == "resolve_dnsname")[0]
		var linux: Dictionary = tools.filter(func(t): return t.id == "dig")[0]
		var common: Dictionary = tools.filter(func(t): return t.id == "nslookup")[0]
		assert(item.investigation_environment == "linux")
		assert(not ToolRunner.supports_target(windows, item))
		assert(ToolRunner.supports_target(linux, item))
		assert(ToolRunner.supports_target(common, item))
		var other := item.duplicate(true)
		other.id = "OTHER"
		assert(not ToolRunner.new().run(common, other).ok)
	assert(catalog.cases.all(func(c): return c.platform in ["windows", "linux", "common"]))
	print("Environment and resource ownership tests passed")
	quit()
