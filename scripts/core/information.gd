class_name Information
extends RefCounted
## 表示する情報とToolへ渡す情報を共通の型にする。

static func normalize(items: Array, source: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw in items:
		var item: Dictionary = raw.duplicate(true)
		item.merge({"category": "basic", "data_type": "text", "draggable": true,
			"tool_input": true, "source": source}, false)
		result.append(item)
	return result

static func from_initial(item: Dictionary) -> Array[Dictionary]:
	var items: Array = []
	for key in item.initial_information:
		items.append({"id": key, "label": key, "value": item.initial_information[key],
			"data_type": item.initial_information_types.get(key, "text")})
	return normalize(items, "initial_information")

static func display(value: Variant) -> String:
	# 構造化された資料は項目として読む。JSON・Commandの文字列はそのまま表示する。
	if value is Dictionary:
		if value.is_empty(): return "なし"
		var lines: PackedStringArray = []
		for key in value:
			var text := display(value[key]).replace("\n", "\n  ")
			var nested: bool = (value[key] is Dictionary or value[key] is Array) and not value[key].is_empty()
			lines.append(str(key) + (":\n  " if nested else ": ") + text)
		return "\n".join(lines)
	if value is Array:
		if value.is_empty(): return "なし"
		var lines: PackedStringArray = []
		for item in value:
			lines.append("• " + display(item).replace("\n", "\n  "))
		return "\n".join(lines)
	return str(value)

static func accepts(tool: Dictionary, item: Dictionary) -> bool:
	if not item.get("tool_input", false) or item.get("data_type", "text") not in tool.get("accepted_information_types", []):
		return false
	for binding in tool.get("input_bindings", []):
		if item.get("source", "") == binding.source and item.get("id", "") == binding.id:
			return true
	return false

static func input_hint(tool: Dictionary) -> String:
	return tool.get("input_hint", "")
