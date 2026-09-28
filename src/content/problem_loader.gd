class_name ProblemLoader
extends RefCounted
## A single problem is validated without a pack, UI, directory, or glossary provider.
static var _schema: Dictionary = { }


static func parse(bytes: PackedByteArray, origin: Dictionary = { }) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return {
			"problem": { },
			"errors": PackedStringArray(
				["JSON:%d: %s" % [parser.get_error_line(), parser.get_error_message()]]
			),
		}
	return load_value(parser.data, origin)


static func load_value(value: Variant, origin: Dictionary = { }) -> Dictionary:
	if _schema.is_empty():
		_schema = ContentSchema.read_schema(ContentSchema.PROBLEM)
	var errors := ContentSchema.check(value, _schema)
	if not errors.is_empty():
		return { "problem": { }, "errors": errors }
	var item: Dictionary = value.duplicate(true)
	item.source_id = origin.get("source_id", "standalone")
	item.source_path = origin.get("path", "")
	item.definition_hash = JSON.stringify(value, "", true).sha256_text()
	item.key = item.id if item.source_id == "builtin" else item.source_id + "/" + item.id
	item.difficulty = item.get("difficulty", "unrated")
	item.information = Information.normalize(item.initial.information, "initial_information")
	var initial_ids := { }
	for info in item.information:
		if initial_ids.has(info.id):
			errors.append("initial.information: 重複したID: " + info.id)
		initial_ids[info.id] = true
	var ids := { "initial_information": true }
	for resource in item.resources:
		if ids.has(resource.id):
			errors.append("resources: 重複または予約されたID: " + resource.id)
		ids[resource.id] = true
		resource.merge(
			{
				"label": resource.name,
				"description": "資料を表示します。",
				"accepted_information_types": [],
				"environments": [],
				"case_id": item.key,
			},
			false,
		)
		resource.group = resource.kind + ":" + resource.get("section", "")
		resource.group_label = resource.get("section", ContentLabels.KINDS[resource.kind])
		var result_ids := {
			"output": true,
			"content": true,
			"submission_type": true,
			"submission_value": true,
			"warning": true,
		}
		for fact in resource.result.get("information", []):
			if result_ids.has(fact.id):
				errors.append(resource.id + ": 出力情報IDの重複または予約語: " + fact.id)
			result_ids[fact.id] = true
		if resource.result.has("by_environment"):
			var variants: Dictionary = resource.result.by_environment
			if variants.size() != resource.environments.size() or not resource.environments.all(
					func(os):
						return variants.has(os),
				):
				errors.append(resource.id + ": 対応OSとOS別出力が一致しません。")
		for content in [resource.result.content] + resource \
				.result \
				.get("by_environment", { }) \
				.values():
			var error := Information.validate_template(
				content,
				resource.result.get("information", []),
				resource.kind != "references",
			)
			if not error.is_empty():
				errors.append(resource.id + ": " + error)
	var alternatives: Dictionary = item.get("evidence_alternatives", { })
	for id in alternatives:
		if id.strip_edges().is_empty() or ids.has(id):
			errors.append("代替証拠IDの重複または予約語: " + id)
		for option in alternatives[id].any_of:
			if not ids.has(option):
				errors.append("代替証拠の資料が存在しません: " + option)
	for id in item.required_evidence:
		if not ids.has(id) and not alternatives.has(id):
			errors.append("必要証拠が存在しません: " + id)
	if errors.is_empty():
		var graph_error := InvestigationInputs.validate_graph(item, item.resources)
		if not graph_error.is_empty():
			errors.append(graph_error)
	if not errors.is_empty():
		return { "problem": { }, "errors": errors }
	item.traits = InvestigationInputs.traits(item)
	return { "problem": item, "errors": errors }


static func identity(item: Dictionary) -> String:
	return ProblemContext.identity(item)
