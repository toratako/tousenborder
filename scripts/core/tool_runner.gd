class_name ToolRunner
extends RefCounted
## 処理の戻り値は {ok: bool, output: String}。信頼できるGDScriptのCallableを登録する。
## 標準処理は模擬の調査結果を読み取る。外部コマンド実行やURLへのアクセスは行わない。

var providers: Dictionary = {}

func _init() -> void:
	register_provider("fixture", _fixture)

func register_provider(id: String, provider: Callable) -> void:
	providers[id] = provider

func run(tool: Dictionary, target: Dictionary) -> Dictionary:
	if not target.get("type", "") in tool.get("target_types", []):
		return {"ok": false, "output": "このツールは対象に対応していません。"}
	var id: String = tool.get("provider", "")
	if not providers.has(id):
		return {"ok": false, "output": "ツールの処理が登録されていません: " + id}
	var result = providers[id].call(tool.duplicate(true), target.duplicate(true))
	if not result is Dictionary or not result.get("ok") is bool or not result.get("output") is String:
		return {"ok": false, "output": "ツールの処理が不正な結果を返しました。"}
	return result

func _fixture(tool: Dictionary, target: Dictionary) -> Dictionary:
	var evidence: Dictionary = target.get("evidence", {})
	if not evidence.has(tool.id):
		return {"ok": false, "output": "このツールの調査結果は用意されていません。証拠がないことは安全の証明にはなりません。"}
	return {"ok": true, "output": evidence[tool.id]}
