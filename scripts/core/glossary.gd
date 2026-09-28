class_name LearningGlossary
extends RefCounted

static func validate(item: Dictionary, terms: Dictionary, resources: Array[Dictionary]) -> String:
	var sources := {}
	for resource in resources:
		sources[resource.id] = resource
	var seen := {}
	for entry in item.get("glossary", []):
		if not terms.has(entry.term_id) or seen.has(entry.term_id):
			return "用語IDが未登録または重複しています: " + entry.term_id
		seen[entry.term_id] = true
		for occurrence in entry.occurrences:
			if occurrence.section == "initial":
				if occurrence.source_id != "initial_information":
					return "initialの取得元はinitial_informationです。"
			elif not sources.has(occurrence.source_id):
				return "用語の登場箇所が存在しません: " + occurrence.source_id
			elif occurrence.section == "submission" and sources[occurrence.source_id].resource_kind != "external_references":
				return "submissionは外部照会のみ指定できます。"
	return ""

static func key(source: String, section: String) -> Array:
	return [source, section]

static func visible_terms(item: Dictionary, terms: Dictionary, resources: Array[Dictionary], viewed: Dictionary) -> Array[Dictionary]:
	var sources := {}
	for resource in resources:
		if ToolRunner.supports_target(resource, item):
			sources[resource.id] = resource
	var result: Array[Dictionary] = []
	for entry in item.get("glossary", []):
		var tags: Array[String] = []
		for occurrence in entry.occurrences:
			if not viewed.has(key(occurrence.source_id, occurrence.section)):
				continue
			if occurrence.section == "initial":
				tags.append("初期情報")
			elif sources.has(occurrence.source_id):
				var resource: Dictionary = sources[occurrence.source_id]
				var suffix: String = {"overview": "の案内", "submission": "の送信確認", "result": "" if resource.resource_kind == "references" else "の実行結果"}[occurrence.section]
				tags.append(resource.label + suffix)
		if not tags.is_empty():
			var term: Dictionary = terms[entry.term_id].duplicate(true)
			term.id = entry.term_id
			term.tags = tags
			result.append(term)
	return result
