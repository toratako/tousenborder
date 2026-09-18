class_name InvestigationInputs
extends RefCounted
## 問題の調査OSで安全な調査だけを辿り、必要な入力・証拠に到達できることを確認する。

static func validate_graph(item: Dictionary, resources: Array[Dictionary]) -> String:
	var facts := {"initial_information": {}}
	for info in item.information:
		facts.initial_information[info.id] = info
	for resource in resources:
		facts[resource.id] = {}
		for info in resource.get("output_information", []):
			facts[resource.id][info.id] = info
	for resource in resources:
		for binding in resource.get("input_bindings", []):
			if not facts.has(binding.source) or not facts[binding.source].has(binding.id):
				return "入力元が存在しません: %s → %s/%s" % [resource.id, binding.source, binding.id]
			var info: Dictionary = facts[binding.source][binding.id]
			if not info.get("tool_input", true) or info.get("data_type", "text") not in resource.accepted_information_types:
				return "入力元の型がToolに対応していません: " + resource.id
	var os := ToolRunner.investigation_environment(item)
	var obtained := {"initial_information": facts.initial_information.duplicate(true)}
	var available := {"initial_information": true}
	var pending: Array = resources.filter(func(resource): return ToolRunner.supports_target(resource, item))
	while not pending.is_empty():
		var progress := false
		for resource in pending.duplicate():
			var bindings: Array = resource.get("input_bindings", [])
			var ready: bool = resource.resource_kind == "references" or bindings.any(func(binding): return obtained.get(binding.source, {}).has(binding.id))
			if not ready: continue
			# 許可された外部照会も証拠・後続入力に使える。不適切な調査への依存は拒否する。
			if resource.get("correct_usage", true):
				available[resource.id] = true
				obtained[resource.id] = {}
				for info in resource.get("output_information", []):
					if info.get("tool_input", true): obtained[resource.id][info.id] = info
			pending.erase(resource)
			progress = true
		if not progress: return "この調査OSで安全に取得できない入力です: " + os + " / " + pending[0].id
	for id in item.required_evidence:
		if not evidence_options(item, id).any(func(option): return available.has(option)):
			return "この調査OSで必要証拠を安全に取得できません: " + os + " / " + id
	return ""

static func evidence_options(item: Dictionary, id: String) -> Array:
	return item.get("evidence_alternatives", {}).get(id, {}).get("any_of", [id])
