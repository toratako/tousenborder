class_name LearningGlossary
extends RefCounted
## Optional game help. Local term definitions travel with a standalone problem.
static var _common: Dictionary = { }


static func common_terms() -> Dictionary:
	if _common.is_empty():
		var data: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/glossary/security.json")
		)
		if data is Dictionary and ContentSchema.validate(data, ContentSchema.GLOSSARY).is_empty():
			_common = data.terms
	return _common.duplicate(true)


static func key(source: String, section: String) -> Array:
	return [source, section]


static func visible_terms(
	item: Dictionary,
	terms: Dictionary,
	resources: Array,
	viewed: Dictionary,
) -> Array[Dictionary]:
	var definitions := terms.merged(item.get("glossary", { }), true)
	var ids: Array = []
	if viewed.has(key("initial_information", "initial")):
		ids.append_array(item.initial.get("terms", []))
	for resource in resources:
		if not ProblemContext.supports_target(resource, item):
			continue
		for section in ["overview", "result", "submission"]:
			if not viewed.has(key(resource.id, section)):
				continue
			var block: Dictionary = resource if section == "overview" else resource.get(
				section,
				{ },
			)
			ids.append_array(block.get("terms", []))
	var result: Array[Dictionary] = []
	var seen := { }
	for id in ids:
		if seen.has(id) or not definitions.has(id):
			continue
		seen[id] = true
		var term: Dictionary = definitions[id].duplicate(true)
		term.id = id
		result.append(term)
	return result
