class_name ToolRunner
extends RefCounted
## 検証済みの問題内資料を表示する。外部コマンドやネットワーク通信は実行しない。

static func investigation_environment(target: Dictionary) -> String:
	var platform: String = target.get("platform", "common")
	return target.get("investigation_environment", "windows" if platform == "common" else platform)

static func supports_target(tool: Dictionary, target: Dictionary) -> bool:
	var environments: Array = tool.get("environments", [])
	return environments.is_empty() or investigation_environment(target) in environments

func run(tool: Dictionary, target: Dictionary, input: Dictionary = {}) -> Dictionary:
	if tool.get("case_id", "") != target.get("id", ""):
		return {"ok": false, "output": "この案件の資料ではありません。"}
	if not supports_target(tool, target):
		return {"ok": false, "output": "この調査OSには対応していません。"}
	if tool.resource_kind != "references" and (input.is_empty() or not Information.accepts(tool, input)):
		return {"ok": false, "output": "対応する対象の情報を指定してください。"}
	var items: Array = []
	if tool.resource_kind == "external_references":
		items.append({"id": "submission_type", "label": "送信する情報", "value": tool.submission_type, "tool_input": false})
		items.append({"id": "submission_value", "label": "送信内容", "value": tool.submission_value, "tool_input": false})
		items.append({"id": "warning", "label": "注意", "value": tool.confidentiality_warning, "tool_input": false})
	if tool.resource_kind == "references":
		items.append({"id": "content", "label": "照合用情報", "value": tool.content, "tool_input": false, "draggable": false})
	else:
		var output: String = tool.get("output_by_environment", {}).get(investigation_environment(target), tool.output)
		items.append({"id": "output", "label": "調査結果", "value": output, "data_type": "console", "tool_input": false, "draggable": false})
	items.append_array(tool.get("output_information", []))
	var lines: PackedStringArray = []
	for item in items:
		lines.append(item.label + ": " + Information.display(item.value))
	return {"ok": true, "output": "\n".join(lines), "information": Information.normalize(items, tool.id)}
