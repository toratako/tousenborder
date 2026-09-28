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

static func validate_template(value: Variant, facts: Array, accepts_input: bool) -> String:
	if value is Dictionary or value is Array:
		for part in value.values() if value is Dictionary else value:
			var error := validate_template(part, facts, accepts_input)
			if not error.is_empty(): return error
	elif value is String:
		var expression := RegEx.create_from_string("\\{\\{([^{}]+)\\}\\}")
		for token in expression.search_all(value):
			var id := token.get_string(1)
			if id == "input" and accepts_input: continue
			if id.begins_with("fact:") and facts.any(func(fact): return fact.id == id.substr(5)): continue
			return "表示テンプレートの参照が存在しません: " + id
	return ""

static func render(value: Variant, facts: Array, input: Dictionary = {}) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = render(value[key], facts, input)
		return result
	if value is Array: return value.map(func(part): return render(part, facts, input))
	if not value is String: return value
	# Only named data substitutions are supported. Inserted values are never evaluated again.
	var expression := RegEx.create_from_string("\\{\\{([^{}]+)\\}\\}")
	var result: String = value
	var tokens := expression.search_all(value)
	tokens.reverse()
	for token in tokens:
		var id := token.get_string(1)
		var replacement: Variant = input.get("value", "")
		if id.begins_with("fact:"):
			for fact in facts:
				if fact.id == id.substr(5): replacement = fact.value
		result = result.substr(0, token.get_start()) + display(replacement) + result.substr(token.get_end())
	return result

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
