class_name InvestigationInputs
extends RefCounted
## Input reachability is shared by validation and derived investigation features.


static func validate_graph(item: Dictionary, resources: Array) -> String:
	var facts := { "initial_information": { } }
	for info in item.information:
		facts.initial_information[info.id] = info
	for resource in resources:
		facts[resource.id] = { }
		for info in resource.result.get("information", []):
			facts[resource.id][info.id] = info
	for resource in resources:
		for binding in resource.get("input_bindings", []):
			if not facts.has(binding.source) or not facts[binding.source].has(binding.id):
				return "入力元が存在しません: %s → %s/%s" % [resource.id, binding.source, binding.id]
			var info: Dictionary = facts[binding.source][binding.id]
			if (
				not info.get("tool_input", true)
				or info.data_type not in resource.accepted_information_types
			):
				return "入力元の型がToolに対応していません: " + resource.id
	var route := reachable(item)
	if not route.pending.is_empty():
		return "この調査OSで安全に取得できない入力です: " + str(route.pending[0].id)
	for id in item.required_evidence:
		if not evidence_options(item, id).any(
			func(option):
				return route.available.has(option),
		):
			return "この調査OSで必要証拠を安全に取得できません: " + id
	return ""


static func reachable(item: Dictionary, without_external := false) -> Dictionary:
	var obtained := { "initial_information": { } }
	for info in item.information:
		if info.get("tool_input", true):
			obtained.initial_information[info.id] = true
	var available := { "initial_information": true }
	var pending: Array = item.resources.filter(
		func(resource):
			return (
				ProblemContext.supports_target(resource, item)
				and (not without_external or resource.kind != "external_references")
			),
	)
	while not pending.is_empty():
		var progress := false
		for resource in pending.duplicate():
			var bindings: Array = resource.get("input_bindings", [])
			var ready: bool = (
				resource.kind == "references"
				or bindings.any(
					func(binding):
						return obtained.get(binding.source, { }).has(binding.id),
				)
			)
			if not ready:
				continue
			if resource.get("correct_usage", true):
				available[resource.id] = true
				obtained[resource.id] = { }
				for info in resource.result.get("information", []):
					if info.get("tool_input", true):
						obtained[resource.id][info.id] = true
			pending.erase(resource)
			progress = true
		if not progress:
			break
	return { "available": available, "pending": pending }


static func traits(item: Dictionary) -> Dictionary:
	var kinds: Array[String] = []
	for resource in item.resources:
		if ProblemContext.supports_target(resource, item) and resource.kind not in kinds:
			kinds.append(resource.kind)
	var method := "initial" if kinds.is_empty() else "external" if "external_references" in kinds else "tools" if "tools" in kinds else "references"
	var internal := reachable(item, true)
	var required_external: bool = item.required_evidence.any(
		func(id):
			return not evidence_options(item, id).any(
				func(option):
					return internal.available.has(option),
			),
	)
	return { "method": method, "available_kinds": kinds, "requires_external": required_external }


static func evidence_options(item: Dictionary, id: String) -> Array:
	return item.get("evidence_alternatives", { }).get(id, { }).get("any_of", [id])
