extends RefCounted
## History selects identities; only the currently validated definitions are playable.


static func plan(snapshot: Dictionary, library: ProblemLibrary) -> Dictionary:
	var cases: Array[Dictionary] = []
	var result := { "cases": cases, "missing": 0, "changed": 0, "reason": "" }
	var available := { }
	for item in library.cases:
		available[ProblemContext.identity(item)] = item
	var seen := { }
	for record in snapshot.get("records", []):
		if record.correct:
			continue
		var source: String = record.get("source_id", "")
		# History version 2 predates imports; only the shipped learning pack can be identified.
		if source.is_empty() and snapshot.get("pack", { }).get("id", "") == "learning":
			source = "builtin"
		var key: String = record.id if source == "builtin" else source + "/" + record.id
		if seen.has(key):
			continue
		seen[key] = true
		if available.has(key):
			var item: Dictionary = available[key]
			cases.append(item.duplicate(true))
			if record.has("definition_hash") and record.definition_hash != item.definition_hash:
				result.changed += 1
		else:
			result.missing += 1
	if seen.is_empty():
		result.reason = "この審査に誤った問題はありません。"
	elif cases.is_empty():
		result.reason = "誤った問題の教材が読み込まれていません。"
	elif result.missing > 0:
		result.reason = "現在の教材で再挑戦します。未読込・削除済みの%d問は対象外です。" % result.missing
	elif result.changed > 0:
		result.reason = "更新された%d問を含む、現在の教材で再挑戦します。" % result.changed
	else:
		result.reason = "この審査で誤った問題を、現在の教材で再挑戦します。"
	return result


static func selection(cases: Array[Dictionary], library: ProblemLibrary) -> Dictionary:
	var result := { }
	var labels := {
		"level": ContentLabels.DIFFICULTIES,
		"category": { },
		"platform": ContentLabels.PLATFORMS,
	}
	for item in library.categories:
		labels.category[item.id] = item.label
	for field in labels:
		var ids := { }
		for item in cases:
			ids[item.difficulty if field == "level" else item[field]] = true
		var id: String = ids.keys()[0] if ids.size() == 1 else ""
		result[field] = { "id": id, "label": str(labels[field].get(id, "複数")) }
	return result
