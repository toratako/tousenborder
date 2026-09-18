extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
## 構造検証を通るデータの参照整合性・安全な到達性と読込失敗時の状態を検証する。
var failures := 0
var catalog := Fixtures.catalog()
var schema: Dictionary

class NullProblemCatalog extends ContentCatalog:
	func _read(path: String) -> Variant:
		return Fixtures.pack() if path == DEFAULT_PACK else null

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func raw(id: String) -> Dictionary:
	return Fixtures.raw(id)

func rejected(item: Dictionary, message: String) -> void:
	check(ContentSchema.check(item, schema).is_empty(), "構造は有効: " + message)
	check(not ProblemData.normalize(item, catalog, schema).is_empty(), "意味的に拒否: " + message)

func _initialize() -> void:
	check(catalog.load_pack(), str(catalog.errors))
	if not catalog.errors.is_empty():
		quit(1)
		return
	schema = ContentSchema.read_schema(ContentSchema.PROBLEM)
	for item in catalog.cases:
		check(not item.has("fields") and not item.has("expected") and not item.has("type"), "実行時にも旧フィールドを持たない")
	for tool in catalog.guide_tools():
		check(not tool.has("output") and not tool.has("output_information") and not tool.has("correct_usage"), "ガイドから結果を漏らさない")
	var visible := raw("FIX-VISIBLE-FILE")
	var policy := {"id": "policy", "name": "受入れ形式", "content": "PDFのみ受け入れる。"}
	visible.references = [policy]
	visible.required_evidence = ["initial_information", "policy"]
	check(ProblemData.normalize(visible, catalog, schema).is_empty(), "超初級でReferenceを必要証拠にできる")
	var reference_shift := InspectionShift.new()
	reference_shift.start([visible])
	check(reference_shift.missing_evidence() == ["policy"], "超初級でもReferenceは閲覧するまで未確認")
	check(reference_shift.inspect(catalog.tools_for(visible)[0]).ok, "入力なしでReferenceを閲覧できる")
	check(reference_shift.missing_evidence().is_empty(), "閲覧でReferenceの証拠が揃う")
	var custom_catalog := Fixtures.catalog()
	check(custom_catalog.load_pack(), "追加グループ用のPack読込")
	custom_catalog.resource_groups.policy_documents = {"id": "policy_documents", "label": "規則", "kind": "references"}
	visible = raw("FIX-VISIBLE-FILE")
	visible.resources = {"policy_documents": [{"id": "policy", "name": "受入れ形式", "content": "PDFのみ受け入れる。"}]}
	visible.evidence_alternatives = {"format_policy": {"label": "形式の規則", "any_of": ["policy"]}}
	visible.required_evidence = ["format_policy"]
	check(ProblemData.normalize(visible, custom_catalog, schema).is_empty(), "超初級で追加Referenceグループと代替証拠を使用できる")
	for kind in ["tools", "external_references"]:
		var source := raw("FIX-FILE") if kind == "tools" else raw("FIX-PRIVATE-FILE")
		var resource: Dictionary = source[kind][0].duplicate(true)
		resource.accepted_information_types = ["file"]
		resource.input_bindings = [{"source": "initial_information", "id": "File名"}]
		for custom in [false, true]:
			visible = raw("FIX-VISIBLE-FILE")
			if custom:
				custom_catalog.resource_groups.extra = {"id": "extra", "label": "追加資料", "kind": kind}
				visible.resources = {"extra": [resource.duplicate(true)]}
			else:
				visible[kind] = [resource.duplicate(true)]
			check(ContentSchema.check(visible, schema).is_empty(), "構造が有効な超初級の調査候補")
			check(ProblemData.normalize(visible, custom_catalog, schema).contains("Referenceのみ"), "超初級のTool・External Referenceは追加グループでも拒否")
	var item := raw("FIX-FILE")
	item.initial_information_types.unknown = "file"
	rejected(item, "未登録の初期情報型")
	item = raw("FIX-FILE")
	item.tools[0].input_bindings[0].id = "missing"
	rejected(item, "存在しない入力")
	item = raw("FIX-FILE")
	item.tools[0].id = "initial_information"
	rejected(item, "予約済み資料ID")
	item = raw("FIX-FILE")
	item.tools[1].id = item.tools[0].id
	rejected(item, "資料ID重複")
	item = raw("FIX-HASH")
	var hash_tool: Dictionary = item.tools.filter(func(t): return t.id == "sha256sum")[0]
	hash_tool.output_information[0].tool_input = false
	rejected(item, "入力不可の出力を参照")
	item = raw("FIX-HASH")
	hash_tool = item.tools.filter(func(t): return t.id == "sha256sum")[0]
	hash_tool.accepted_information_types = ["sha256"]
	hash_tool.input_bindings = [{"source": hash_tool.id, "id": hash_tool.output_information[0].id}]
	rejected(item, "循環参照")
	item = raw("FIX-HASH")
	item.required_evidence = [item.external_references[0].id]
	check(ProblemData.normalize(item, catalog, schema).is_empty(), "適切な外部照会を必要証拠にできる")
	item = raw("FIX-DNS")
	item.required_evidence = ["dig"]
	check(ProblemData.normalize(item, catalog, schema).is_empty(), "共通問題はLinuxだけで必要証拠を取得できれば有効")
	item = raw("FIX-DNS")
	item.required_evidence = ["resolve_dnsname"]
	rejected(item, "共通問題でLinuxでは得られない必要証拠")
	item = raw("FIX-DNS")
	var nslookup: Dictionary = item.tools.filter(func(t): return t.id == "nslookup")[0]
	nslookup.output_by_environment.erase("linux")
	rejected(item, "OS別出力の欠落")
	item = raw("FIX-HASH")
	hash_tool = item.tools.filter(func(t): return t.id == "sha256sum")[0]
	hash_tool.correct_usage = false
	hash_tool.reason = "教材上の不適切な調査"
	rejected(item, "不適切な調査から入力を得る経路")
	# Packは正常な1問を読んだ後で失敗しても、部分的な教材を公開しない。
	var pack: Dictionary = Fixtures.pack()
	pack.problems = [pack.problems[0], "res://data/problems/MISSING.json"]
	var file := FileAccess.open("user://invalid-pack.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(pack))
	file.close()
	check(not catalog.load_pack("user://invalid-pack.json") and catalog.cases.is_empty(), "読込失敗時に案件を公開しない")
	DirAccess.remove_absolute("user://invalid-pack.json")
	check(catalog.load_pack() and catalog.cases.size() == Fixtures.pack().problems.size(), "失敗後に正常教材を再読込")
	var null_catalog := NullProblemCatalog.new()
	check(not null_catalog.load_pack() and null_catalog.cases.is_empty() and not null_catalog.errors.is_empty(), "JSON nullの問題を黙って飛ばさない")
	print("Content semantics tests: %d failures" % failures)
	quit(1 if failures else 0)
