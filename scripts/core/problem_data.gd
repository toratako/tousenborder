class_name ProblemData
extends RefCounted
## Schema検証後の問題に実行時の表示情報だけを付加する。別名変換は行わない。

static func normalize(item: Dictionary, catalog: ContentCatalog, schema: Dictionary) -> String:
	if not catalog.categories.any(func(category): return category.id == item.category):
		return "未登録のcategory: " + item.category
	for key in item.initial_information:
		if key.strip_edges().is_empty():
			return "initial_information のキーは空にできません。"
	for key in item.initial_information_types:
		if not item.initial_information.has(key):
			return "型を指定した初期情報が存在しません: " + key
	item.information = Information.from_initial(item)
	item.merge({"resources": {}}, false)
	for group in item.resources:
		if not catalog.resource_groups.has(group) or group in ContentCatalog.RESOURCE_GROUPS:
			return "resources には追加登録した資料グループを指定してください: " + group
	var ids := {"initial_information": true}
	for group in catalog.resource_groups:
		var source: Dictionary = item if group in ContentCatalog.RESOURCE_GROUPS else item.resources
		var kind: String = catalog.resource_groups[group].kind
		var definition: String = {"tools": "tool", "references": "reference", "external_references": "external"}[kind]
		# 追加グループも登録されたkindと同じSchemaに従う。
		var resource_schema: Dictionary = {"$ref": "#/$defs/" + definition, "$defs": schema["$defs"]}
		for resource in source.get(group, []):
			var errors := ContentSchema.check(resource, resource_schema)
			if not errors.is_empty(): return group + ": " + "; ".join(errors)
			if item.level == "very_beginner" and kind != "references":
				return "超初級の調査にはReferenceのみ使用できます。"
			if ids.has(resource.id): return "資料IDが重複しています: " + resource.id
			ids[resource.id] = true
			resource.merge({"label": resource.name, "description": "資料を表示します。",
				"accepted_information_types": [], "environments": [], "case_id": item.id,
				"group": group, "resource_kind": kind}, false)
			if resource.has("output_by_environment"):
				if resource.output_by_environment.size() != resource.environments.size():
					return "対応OSごとの模擬出力が必要です: " + resource.id
				for os in resource.environments:
					if not resource.output_by_environment.has(os): return "模擬出力がないOS: " + os
			var output_ids := {"output": true, "content": true, "submission_type": true, "submission_value": true, "warning": true}
			for info in resource.get("output_information", []):
				if output_ids.has(info.id): return "出力情報IDの重複または予約語: " + info.id
				output_ids[info.id] = true
	var investigations := catalog.tools_for(item)
	var has_external := investigations.any(func(resource): return resource.resource_kind == "external_references")
	var has_tool := investigations.any(func(resource): return resource.resource_kind == "tools")
	if item.level == "beginner" and has_external:
		return "External Referenceがある初級はbeginner_externalに分類してください。"
	if item.level == "beginner" and not has_tool:
		return "Toolを使わない初級はbeginner_referenceに分類してください。"
	if item.level == "beginner_reference" and (investigations.is_empty() or has_tool or has_external):
		return "beginner_referenceにはReferenceのみを配置してください。"
	if item.level == "beginner_external" and not has_external:
		return "beginner_externalにはExternal Referenceが必要です。"
	var alternatives: Dictionary = item.get("evidence_alternatives", {})
	for id in alternatives:
		if id.strip_edges().is_empty() or ids.has(id): return "代替証拠IDの重複または予約語: " + id
		for option in alternatives[id].any_of:
			if not ids.has(option): return "代替証拠の資料が存在しません: " + option
	for id in item.required_evidence:
		if not ids.has(id) and not alternatives.has(id): return "必要証拠が存在しません: " + id
	return InvestigationInputs.validate_graph(item, catalog.tools_for(item))
