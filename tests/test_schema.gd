extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
## ゲーム内Schema検証の型・分岐・参照と、教材の未知キー拒否を検証する。
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)


func _initialize() -> void:
	check(ContentSchema.check(1.0, { "type": "integer", "const": 1 }).is_empty(), "JSON整数1.0")
	check(not ContentSchema.check(true, { "type": "integer" }).is_empty(), "boolは整数ではない")
	check(not ContentSchema.check(INF, { "type": "number" }).is_empty(), "非有限数を拒否")
	check(not ContentSchema.check([{ "x": 1 }, { "x": 1.0 }], { "uniqueItems": true }).is_empty(), "深いJSON等値")
	check(ContentSchema.check([true, 1], { "uniqueItems": true }).is_empty(), "boolと数値は別")
	check(not ContentSchema.check({ }, { "properties": { "unused": { "unknown_keyword": true } } }).is_empty(), "未使用のSchemaでも未対応キーワードを拒否")
	check(not ContentSchema.check({ }, { "$ref": "https://example.test/schema" }).is_empty(), "外部Schema参照を拒否")
	check(not ContentSchema.check({ }, {
			"$ref": "#/$defs/text/type",
			"$defs": { "text": { "type": "string" } },
		}).is_empty(), "Schema以外への参照を拒否")
	for malformed in [
		{ "enum": "abc" },
		{ "required": [1] },
		{ "type": [1] },
		{ "minLength": true },
		{ "uniqueItems": "yes" },
		{ "allOf": [] },
	]:
		check(not ContentSchema.check({ }, malformed).is_empty(), "不正Schemaを実行時エラーにせず拒否")
	check(ContentSchema.check({ "x": [false, 2, { "y": "ok" }] }, ContentSchema.read_schema(
			ContentSchema.PROBLEM
		)["$defs"]
		.value
		.merged({ "$defs": ContentSchema.read_schema(ContentSchema.PROBLEM)["$defs"] })).is_empty(), "再帰的JSON値")
	var problem: Dictionary = Fixtures.raw("FIX-FILE")
	check(ContentSchema.validate(problem, ContentSchema.PROBLEM).is_empty(), "正式な問題")
	for key in ["fields", "evidence", "expected", "type", "level", "provider", "require_evidence"]:
		var changed := problem.duplicate(true)
		changed[key] = { }
		check(
			not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(),
			"旧キー拒否: " + key,
		)
	var changed := problem.duplicate(true)
	Fixtures.resources(changed, "tools")[0].input_bindings[0].extra = true
	check(not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(), "入れ子の未知キー拒否")
	changed = problem.duplicate(true)
	Fixtures.resources(changed, "tools")[0].correct_usage = false
	Fixtures.resources(changed, "tools")[0].erase("reason")
	check(not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(), "調査の適否には理由が必要")
	changed = problem.duplicate(true)
	changed.inspired_by = "Example"
	changed.sources = []
	check(not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(), "実例条件のif/then")
	for value in ["approve", "deny", "ALLOW", "BLOCK"]:
		changed = problem.duplicate(true)
		changed.ground_truth = value
		check(not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(), "旧判定値拒否")
	for required in ["accepted_information_types", "input_bindings", "input_hint"]:
		changed = problem.duplicate(true)
		Fixtures.resources(changed, "tools")[0].erase(required)
		check(
			not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(),
			"Toolの入力契約: " + required,
		)
	for invalid_source in [
		"http://example.test",
		"file:///tmp/source",
		"https://invalid space.test",
	]:
		changed = problem.duplicate(true)
		changed.sources = [invalid_source]
		check(not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(), "出典URL形式")
	for old_difficulty in ["very_beginner", "beginner_reference", "beginner_external", "applied"]:
		changed = problem.duplicate(true)
		changed.difficulty = old_difficulty
		check(
			not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(),
			"調査形式を難易度に入れない",
		)
	changed = problem.duplicate(true)
	changed.initial.information = []
	check(not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(), "空の初期情報を拒否")
	changed = Fixtures.raw("FIX-HASH")
	Fixtures.resources(changed, "external_references")[0].submission.value = "duplicate"
	check(not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(), "送信値の二重定義を拒否")
	changed = problem.duplicate(true)
	changed.initial.terms = ["file", "file"]
	check(not ContentSchema.validate(changed, ContentSchema.PROBLEM).is_empty(), "表示箇所の用語重複を拒否")
	var pack := {
		"schema_version": 2,
		"id": "test",
		"title": "Test",
		"chapters": ["chapters/01.json"],
	}
	for key in [
		"cases",
		"tools",
		"actions",
		"platforms",
		"difficulties",
		"day",
		"npcs",
		"environment",
		"require_evidence",
		"require_tool_inputs",
	]:
		changed = pack.duplicate(true)
		changed[key] = []
		check(
			not ContentSchema.validate(changed, ContentSchema.PACK).is_empty(),
			"旧Packキー拒否: " + key,
		)
	print("Schema tests: %d failures" % failures)
	quit(1 if failures else 0)
