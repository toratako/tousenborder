extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func rejected(item: Dictionary, message: String) -> void:
	check(ContentSchema.validate(item, ContentSchema.PROBLEM).is_empty(), "構造は有効: " + message)
	check(not ProblemLoader.load_value(item).errors.is_empty(), "意味的に拒否: " + message)

func _initialize() -> void:
	var library := Fixtures.library()
	check(library.load_builtin(), str(library.errors))
	var visible := Fixtures.raw("FIX-VISIBLE-FILE")
	visible.erase("difficulty")
	visible.category = "custom"
	visible.category_label = "独自分野"
	visible.resources = [{"id": "policy", "name": "規則", "kind": "references", "section": "社内資料", "result": {"content": "PDFのみ受け入れる。"}}]
	visible.required_evidence = ["policy"]
	var loaded := ProblemLoader.load_value(visible)
	check(loaded.errors.is_empty(), "Packや分類登録なしで問題を検証: " + str(loaded.errors))
	check(loaded.problem.difficulty == "unrated" and loaded.problem.traits.method == "references", "難易度未設定と自動分類")
	var shift := InspectionShift.new()
	shift.start([loaded.problem])
	check(shift.missing_evidence() == ["policy"], "未閲覧のReference")
	check(shift.inspect(loaded.problem.resources[0]).ok and shift.missing_evidence().is_empty(), "単独問題の資料を閲覧")
	for tool in library.guide_tools():
		check(not tool.has("result") and not tool.has("correct_usage"), "ガイドに結果を漏らさない")
	var item := Fixtures.raw("FIX-FILE")
	item.initial.information.append(item.initial.information[0].duplicate(true))
	rejected(item, "初期情報ID重複")
	item = Fixtures.raw("FIX-FILE")
	Fixtures.resources(item, "tools")[0].input_bindings[0].id = "missing"
	rejected(item, "存在しない入力")
	item = Fixtures.raw("FIX-FILE")
	item.resources[0].id = "initial_information"
	rejected(item, "予約済み資料ID")
	item = Fixtures.raw("FIX-FILE")
	item.resources[1].id = item.resources[0].id
	rejected(item, "資料ID重複")
	item = Fixtures.raw("FIX-HASH")
	Fixtures.resource(item, "sha256sum").result.information[0].tool_input = false
	rejected(item, "入力不可の出力を参照")
	item = Fixtures.raw("FIX-HASH")
	var hash_tool := Fixtures.resource(item, "sha256sum")
	hash_tool.accepted_information_types = ["sha256"]
	hash_tool.input_bindings = [{"source": hash_tool.id, "id": hash_tool.result.information[0].id}]
	rejected(item, "循環参照")
	item = Fixtures.raw("FIX-HASH")
	item.required_evidence = [Fixtures.resources(item, "external_references")[0].id]
	check(ProblemLoader.load_value(item).problem.traits.requires_external, "必須外部照会を導出")
	item = Fixtures.raw("FIX-DNS")
	item.required_evidence = ["dig"]
	check(ProblemLoader.load_value(item).errors.is_empty(), "共通問題のLinux経路")
	item.required_evidence = ["resolve_dnsname"]
	rejected(item, "共通問題でLinuxにない必要証拠")
	item = Fixtures.raw("FIX-DNS")
	Fixtures.resource(item, "nslookup").result.by_environment.erase("linux")
	rejected(item, "OS別出力の欠落")
	item = Fixtures.raw("FIX-HASH")
	Fixtures.resource(item, "sha256sum").correct_usage = false
	Fixtures.resource(item, "sha256sum").reason = "不適切な調査"
	rejected(item, "不適切な調査からの入力")
	item = Fixtures.raw("FIX-HASH")
	check(not ProblemLoader.load_value(item).problem.traits.requires_external, "任意の外部照会と必須を区別")
	Fixtures.resource(item, "sha256sum").accepted_information_types = ["domain"]
	rejected(item, "入力の型の不一致")
	item = Fixtures.raw("FIX-HASH")
	Fixtures.resource(item, "sha256sum").result.information[0].id = "output"
	rejected(item, "出力情報の予約ID")
	item = Fixtures.raw("FIX-DNS")
	item.evidence_alternatives[" "] = {"label": "空のID", "any_of": ["nslookup"]}
	rejected(item, "空の代替証拠ID")
	var guide_library := ProblemLibrary.new()
	check(guide_library.load_builtin(), "公開教材のガイド")
	var guide := guide_library.guide_tools()
	for label in ["Get-FileHash", "Sigcheck"]:
		var variants := guide.filter(func(tool): return tool.label == label)
		check(variants.size() >= 2 and variants.any(func(tool): return "process" in tool.accepted_information_types or "pid" in tool.accepted_information_types), "入力の異なるToolを保持: " + label)
	guide_library.cases.reverse()
	var reversed := guide_library.guide_tools()
	for tool in guide:
		check(reversed.any(func(other): return other.label == tool.label and other.accepted_information_types == tool.accepted_information_types and other.description == tool.description), "ガイドは登録順で情報を失わない")
	var before := library.cases.duplicate(true)
	check(not library.add_source(Fixtures.source([item], "invalid")), "無効な読込元を拒否")
	check(library.cases == before, "読込失敗で既存問題を変更しない")
	var null_source := ContentSource.new()
	null_source.id = "null"
	null_source.files["problems/null.json"] = "null".to_utf8_buffer()
	check(not library.add_source(null_source), "JSON nullを黙って飛ばさない")
	print("Content semantics tests: %d failures" % failures)
	quit(1 if failures else 0)
