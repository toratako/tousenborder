extends RefCounted
## 履歴は対象IDの選別にだけ使用し、出題は検証済みの現行教材から作る。

static func plan(snapshot: Dictionary, catalog: ContentCatalog) -> Dictionary:
	var cases: Array[Dictionary] = []
	var result := {"cases": cases, "missing": 0, "reason": ""}
	if not catalog.errors.is_empty():
		result.reason = "教材を読み込めないため再挑戦できません。"
		return result
	if snapshot.get("pack", {}).get("id", "") != catalog.pack_id:
		result.reason = "現在の教材とは異なる勤務履歴です。"
		return result
	var available := {}
	for item in catalog.cases: available[item.id] = item
	var seen := {}
	for record in snapshot.get("records", []):
		if record.correct or seen.has(record.id): continue
		seen[record.id] = true
		if available.has(record.id):
			cases.append(available[record.id].duplicate(true))
		else:
			result.missing += 1
	if seen.is_empty():
		result.reason = "この勤務に誤った問題はありません。"
	elif cases.is_empty():
		result.reason = "誤った問題が現在の教材にありません。"
	elif result.missing > 0:
		result.reason = "現在の教材で再挑戦します。削除された%d問は対象外です。" % result.missing
	else:
		result.reason = "この勤務で誤った問題を、現在の教材で再挑戦します。"
	return result

static func selection(cases: Array[Dictionary], catalog: ContentCatalog) -> Dictionary:
	var result := {}
	var labels := {"level": {}, "category": {}, "platform": {}}
	for key in catalog.difficulties: labels.level[key] = catalog.difficulties[key].label
	for item in catalog.categories: labels.category[item.id] = item.label
	for key in catalog.platforms: labels.platform[key] = catalog.platforms[key].label
	for field in labels:
		var ids := {}
		for item in cases: ids[item[field]] = true
		var id: String = ids.keys()[0] if ids.size() == 1 else ""
		result[field] = {"id": id, "label": str(labels[field].get(id, "複数"))}
	return result
