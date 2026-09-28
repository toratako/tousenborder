class_name ResultAnalysis
extends RefCounted
## 保存済みの事実だけを集計する。教材の現在の正解や資料には依存しない。
const CATEGORY_LABELS = ContentLabels.CATEGORIES
const LEVEL_LABELS = ContentLabels.DIFFICULTIES
# 教材内の暫定基準。心理尺度・資格認定ではない。
const RULES := {
	"style_min_cases": 3,
	"careful_rate": 0.8,
	"intuitive_rate": 0.5,
	"level_min_cases": 5,
	"pro_min_cases": 10,
	"practice_rate": 0.7,
	"pro_rate": 0.9,
	"pro_harder_correct": 3,
	"pro_each_verdict": 1,
}
const COMBINATIONS := {
	"intuitive_beginner": "少ない確認で判断を進める傾向があります。必要な資料を一つずつ確認してみましょう。",
	"intuitive_practice": "少ない確認でも正しく判断できた問題があります。判定前に根拠を確かめましょう。",
	"careful_beginner": "必要な情報を確認できています。集めた情報を規則と照合する練習をしてみましょう。",
	"careful_practice": "根拠を確認しながら判断できています。情報の一致・不一致にも注目してみましょう。",
	"careful_pro": "今回の出題範囲で、根拠をそろえた判断と高い正答率を両立できています。",
	"middle_beginner": "確認の進め方は問題によって異なります。必要な情報をそろえ、規則と照合してみましょう。",
	"middle_practice": "多くの問題で正しく判断できています。確認が足りなかった問題も振り返ってみましょう。",
}


static func ratio(part: int, total: int) -> float:
	return float(part) / total if total > 0 else 0.0


static func analyze(snapshot: Dictionary) -> Dictionary:
	var result := {
		"answered": 0,
		"correct": 0,
		"complete": 0,
		"operations": 0,
		"skipped": 0,
		"unsafe": 0,
		"failed": 0,
		"evaluated_operations": 0,
		"false_allow": 0,
		"false_block": 0,
		"expected_allow": 0,
		"expected_block": 0,
		"eligible": 0,
		"eligible_complete": 0,
		"unknown_evidence": 0,
		"elapsed_seconds": snapshot.get("elapsed_seconds", 0.0),
		"categories": { },
		"levels": { },
		"harder_correct": 0,
		"unknown_level": 0,
		"is_retry": snapshot.has("retry_of"),
		"review": { "unsafe": [], "false_allow": [], "incomplete": [] },
	}
	for id in CATEGORY_LABELS:
		result.categories[id] = {
			"label": CATEGORY_LABELS[id],
			"answered": 0,
			"correct": 0,
			"errors": [],
		}
	for record in snapshot.get("records", []):
		var index: int = result.answered
		result.answered += 1
		var correct: bool = record.correct
		var complete: bool = record.missing_evidence.is_empty()
		if correct:
			result.correct += 1
		if complete:
			result.complete += 1
		if not complete:
			result.review.incomplete.append(index)
		var level: String = record.get("level", "unknown")
		result.levels[level] = result.levels.get(level, 0) + 1
		if not LEVEL_LABELS.has(level) or level == "unrated":
			result.unknown_level += 1
		if level in ["intermediate", "advanced"] and correct:
			result.harder_correct += 1
		if record.ground_truth == "allow":
			result.expected_allow += 1
			if not correct:
				result.false_block += 1
		else:
			result.expected_block += 1
			if not correct:
				result.false_allow += 1
				result.review.false_allow.append(index)
		if not result.categories.has(record.category):
			result.categories[record.category] = {
				"label": record.get("category_label", record.category),
				"answered": 0,
				"correct": 0,
				"errors": [],
			}
		if result.categories[record.category].answered == 0 and record.has("category_label"):
			result.categories[record.category].label = record.category_label
		result.categories[record.category].answered += 1
		if correct:
			result.categories[record.category].correct += 1
		else:
			result.categories[record.category].errors.append(index)
		if not record.has("investigation_required"):
			result.unknown_evidence += 1
		elif record.investigation_required:
			result.eligible += 1
			if complete:
				result.eligible_complete += 1
		for observation in record.observations:
			if observation.get("skipped", false):
				result.skipped += 1
				continue
			result.operations += 1
			if observation.ok and observation.has("correct_usage"):
				result.evaluated_operations += 1
			if not observation.ok:
				result.failed += 1
			elif not observation.get("correct_usage", true):
				result.unsafe += 1
				if not index in result.review.unsafe:
					result.review.unsafe.append(index)
	result.accuracy = ratio(result.correct, result.answered)
	result.evidence_rate = ratio(result.complete, result.answered)
	result.style = _style(result)
	result.level = _level(result)
	result.scope = _scope(result)
	result.description = COMBINATIONS.get(
		result.style.id + "_" + result.level.id,
		"今回の出題範囲での結果です。記録が足りない項目は判定を保留しています。",
	)
	result.advice = _advice(result)
	return result


static func radar_metrics(data: Dictionary) -> Array[Dictionary]:
	return [
		{
			"label": "危険を見抜く",
			"part": data.expected_block - data.false_allow,
			"total": data.expected_block,
			"unit": "問",
			"hint": "BLOCKが正解の問題を、正しく遮断できた割合。",
		},
		{
			"label": "安全を見分ける",
			"part": data.expected_allow - data.false_block,
			"total": data.expected_allow,
			"unit": "問",
			"hint": "ALLOWが正解の問題を、正しく許可できた割合。",
		},
		{
			"label": "根拠をそろえる",
			"part": data.complete,
			"total": data.answered,
			"unit": "問",
			"hint": "判断の根拠となる情報をそろえて判定した割合。初期情報だけで足りる問題も含み、理解度を表すものではありません。",
		},
	]


static func operation_segments(data: Dictionary) -> Array[Dictionary]:
	# 実行結果の内訳。完了は操作の適切さを意味しない。送信見送りは含めない。
	return [
		{ "label": "実行完了", "count": data.operations - data.failed },
		{ "label": "実行失敗", "count": data.failed },
	]


static func radar_findings(data: Dictionary) -> Array[String]:
	# 観測された結果だけを説明し、未出題を達成扱いしない。
	return [
		"危険な対象は出題されていません。" if data.expected_block == 0 else (
			"危険な対象をすべて遮断できました。" if data.false_allow == 0 else "%d問で危険な対象を許可していました。"
			% data.false_allow
		),
		"安全な対象は出題されていません。" if data.expected_allow == 0 else (
			"安全な対象をすべて許可できました。" if data.false_block == 0 else "%d問で安全な対象を遮断していました。"
			% data.false_block
		),
		"判定した問題がありません。" if data.answered == 0 else (
			"全問で必要な情報をそろえて判定できました。" if data.complete == data.answered else "%d問で情報が足りないまま判定していました。"
			% (data.answered - data.complete)
		),
	]


static func _style(data: Dictionary) -> Dictionary:
	var pending := {
		"id": "pending",
		"label": "スタイル判定保留",
		"reason": "追加調査が必要な問題が%d問以上で判定します（今回%d問）。" % [RULES.style_min_cases, data.eligible],
	}
	if data.unknown_evidence > 0:
		pending.reason = "調査要否の記録がない問題が%d問あるため、スタイルは判定保留です。" % data.unknown_evidence
		return pending
	if data.eligible < RULES.style_min_cases:
		return pending
	var complete_rate := ratio(data.eligible_complete, data.eligible)
	var id := "middle"
	var label := "直感・慎重の中間"
	if complete_rate >= RULES.careful_rate:
		id = "careful"
		label = "慎重型"
	elif complete_rate <= RULES.intuitive_rate:
		id = "intuitive"
		label = "直感型"
	return {
		"id": id,
		"label": label,
		"reason": "追加調査が必要な問題で、情報をそろえた判定：%d / %d問（%d％）。確認行動から付けるゲーム内の名称です。"
		% [data.eligible_complete, data.eligible, roundi(complete_rate * 100)],
	}


static func _level(data: Dictionary) -> Dictionary:
	if data.answered == 0:
		return {
			"id": "pending",
			"label": "到達レベル判定保留",
			"reference": true,
			"reason": "判定した問題がありません。",
		}
	var reference: bool = data.answered < RULES.level_min_cases
	var id := "beginner" if data.accuracy < RULES.practice_rate else "practice"
	var label := "初心者級" if id == "beginner" else "実践級"
	var reasons: Array[String] = []
	if reference:
		reasons.append("%d問未満のため参考判定" % RULES.level_min_cases)
	if data.accuracy >= RULES.pro_rate:
		if data.answered < RULES.pro_min_cases:
			reasons.append("プロ級には%d問以上の回答が必要" % RULES.pro_min_cases)
		if data.unknown_level > 0:
			reasons.append("難易度が未評価の問題を含む")
		if data.harder_correct < RULES.pro_harder_correct:
			reasons.append("中級以上での正解が%d問未満" % RULES.pro_harder_correct)
		if (
			data.expected_allow < RULES.pro_each_verdict
			or data.expected_block < RULES.pro_each_verdict
		):
			reasons.append("ALLOW・BLOCK両方の出題が必要")
		if data.false_allow > 0:
			reasons.append("危険な許可が%d問" % data.false_allow)
		if data.unsafe > 0:
			reasons.append("不適切な調査が%d回" % data.unsafe)
		if data.style.id != "careful":
			reasons.append("追加調査の確認率が基準未達、または記録不足")
		if reasons.is_empty():
			id = "pro"
			label = "プロ級"
	var reason := "正答率%d％（%d / %d問）。" % [roundi(data.accuracy * 100), data.correct, data.answered]
	if id == "pro":
		reason += "中級以上で%d問正解。危険な許可・不適切な調査の記録は0件。" % data.harder_correct
	elif data.accuracy >= RULES.pro_rate:
		reason += "プロ級は保留：" + "、".join(reasons) + "。"
	elif reference:
		reason += reasons[0] + "。"
	return { "id": id, "label": label, "reference": reference, "reason": reason }


static func _scope(data: Dictionary) -> String:
	var levels: Array[String] = []
	var grouped := { }
	for id in LEVEL_LABELS:
		if id == "unrated":
			continue
		var label: String = LEVEL_LABELS[id]
		grouped[label] = grouped.get(label, 0) + data.levels.get(id, 0)
	for label in grouped:
		if grouped[label] > 0:
			levels.append("%s %d問" % [label, grouped[label]])
	if data.unknown_level > 0:
		levels.append("難易度未評価 %d問" % data.unknown_level)
	var categories: Array[String] = []
	for category in data.categories.values():
		if category.answered > 0:
			categories.append(category.label)
	var fields := "・".join(categories) if categories.size() <= 2 else "%d分野" % categories.size()
	return "%s　｜　%s　｜　計 %d問" % ["・".join(levels), fields, data.answered] if data.answered > 0 else "出題記録なし"


static func _advice(data: Dictionary) -> Dictionary:
	if data.answered == 0:
		return { "next": "勤務を完了すると結果を確認できます。", "review_indices": [] }
	var weakest: Dictionary = { }
	for category in data.categories.values():
		if not category.errors.is_empty():
			if weakest.is_empty() or category.errors.size() > weakest.errors.size():
				weakest = category
	var next := "別の分野や難易度でも、判断を確かめてみましょう。"
	var indices: Array = []
	if data.unsafe > 0:
		next = "調査手段の利用条件を確認しましょう。外部に送る場合は、機密情報が含まれないかも確認してください。"
		indices = data.review.unsafe
	elif data.false_allow > 0:
		next = "許可する前に、対象の情報と組織の規則を照合しましょう。"
		indices = data.review.false_allow
	elif not weakest.is_empty():
		next = "怪しい特徴だけでなく、承認済みである証拠も確認しましょう。"
		indices = weakest.errors
	elif data.complete < data.answered:
		next = "正解した問題でも、判断に必要な資料を確認してみましょう。"
		indices = data.review.incomplete
	return { "next": next, "review_indices": indices.duplicate() }
