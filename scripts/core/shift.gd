class_name InspectionShift
extends RefCounted
## 画面に依存しない状態管理。判定は案件ごとに一度だけ記録する。
signal changed

var cases: Array[Dictionary] = []
var index := 0
var records: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var judged := false
var runner := ToolRunner.new()
var elapsed_seconds := 0.0
var session_id := ""
var started_at := 0.0

func start(items: Array[Dictionary]) -> void:
	session_id = Crypto.new().generate_random_bytes(16).hex_encode()
	started_at = Time.get_unix_time_from_system()
	cases = items.duplicate(true)
	for item in cases:
		item.investigation_environment = ToolRunner.investigation_environment(item)
	elapsed_seconds = 0.0
	index = 0
	records.clear()
	observations.clear()
	judged = false
	changed.emit()

func current() -> Dictionary:
	return {} if finished() else cases[index]

func finished() -> bool:
	return index >= cases.size()

func tick(delta: float) -> void:
	if finished() or judged or not is_finite(delta) or delta <= 0:
		return
	elapsed_seconds += delta

func inspect(tool: Dictionary, input: Dictionary = {}) -> Dictionary:
	if finished() or judged:
		return {"ok": false, "output": "この案件の審査は終了しています。"}
	if not input.is_empty() and not _owns_information(input):
		return {"ok": false, "output": "この案件で取得した情報を指定してください。"}
	var result := runner.run(tool, current(), input)
	observations.append({"tool_id": tool.id, "tool": tool.label, "ok": result.ok, "output": result.output,
		"input": input.duplicate(true), "information": result.get("information", []).duplicate(true)})
	if result.ok and tool.has("correct_usage"):
		observations.back().merge({"correct_usage": tool.correct_usage, "reason": tool.get("reason", "")})
	changed.emit()
	return result

func decline_external(tool: Dictionary, input: Dictionary = {}) -> bool:
	if finished() or judged or tool.get("case_id", "") != current().id or tool.get("resource_kind", "") != "external_references":
		return false
	if not ToolRunner.supports_target(tool, current()):
		return false
	if not tool.get("accepted_information_types", []).is_empty() and (input.is_empty() or not _owns_information(input) or not Information.accepts(tool, input)):
		return false
	observations.append({"tool_id": tool.id, "tool": tool.label, "ok": true, "output": "外部送信を見送りました。", "information": [], "skipped": true, "input": input.duplicate(true),
		"reason": tool.get("reason", "") if not tool.get("correct_usage", true) else "この照会の結果は取得していません。判断に必要な証拠が揃っているか確認してください。"})
	changed.emit()
	return true

func decide(verdict: String) -> bool:
	if finished() or judged or verdict not in ["allow", "block"]:
		return false
	judged = true
	var missing := missing_evidence()
	records.append({"id": current().id, "title": current().title, "verdict": verdict,
		"request": current().request, "information": current().information.duplicate(true),
		"category": current().category, "level": current().level, "platform": current().platform,
		"investigation_environment": ToolRunner.investigation_environment(current()),
		"correct": verdict == current().ground_truth, "ground_truth": current().ground_truth,
		"explanation": current().explanation, "observations": observations.duplicate(true),
		"missing_evidence": missing,
		"investigation_required": current().get("required_evidence", []).any(func(id): return not "initial_information" in InvestigationInputs.evidence_options(current(), id))})
	changed.emit()
	return true

func missing_evidence() -> Array[String]:
	var missing: Array[String] = []
	if finished(): return missing
	var obtained := ["initial_information"]
	for observation in observations:
		if observation.ok and not observation.get("skipped", false) and observation.get("correct_usage", true):
			obtained.append(observation.get("tool_id", ""))
	for id in current().get("required_evidence", []):
		if not InvestigationInputs.evidence_options(current(), id).any(func(option): return option in obtained):
			missing.append(id)
	return missing

static func investigation_feedback(record: Dictionary) -> String:
	var lines: PackedStringArray = []
	for observation in record.observations:
		if observation.get("skipped", false):
			lines.append(observation.tool + "：外部送信を見送り\n" + observation.reason)
		elif observation.has("correct_usage"):
			lines.append(observation.tool + "：" + ("適切な利用" if observation.correct_usage else "不適切な利用") + "\n" + observation.reason)
	return "\n\n".join(lines)

static func review_text(record: Dictionary) -> String:
	var result: String = record.explanation
	var investigation := investigation_feedback(record)
	if not investigation.is_empty():
		result += "\n\n調査手段の振り返り\n" + investigation
	return result

func unsafe_investigations() -> int:
	var count := 0
	var investigated: Array[Dictionary] = []
	for record in records:
		investigated.append_array(record.observations)
	# 判定済みの調査はrecordsに保存されているため、未判定分だけ加える。
	if not judged:
		investigated.append_array(observations)
	for observation in investigated:
		if observation.get("ok", false) and not observation.get("correct_usage", true):
			count += 1
	return count

func advance() -> bool:
	if not judged or finished():
		return false
	index += 1
	judged = false
	observations.clear()
	changed.emit()
	return true

func score() -> int:
	return records.filter(func(record): return record.correct).size()

func _owns_information(input: Dictionary) -> bool:
	if input.get("case_id", "") != current().id:
		return false
	var candidates: Array = current().get("information", []).duplicate(true)
	for observation in observations:
		if observation.get("ok", false) and not observation.get("skipped", false) and observation.get("correct_usage", true):
			candidates.append_array(observation.get("information", []))
	for item in candidates:
		if item.id == input.get("id") and item.value == input.get("value") and item.get("source", "") == input.get("source", "") and item.get("data_type", "text") == input.get("data_type", "text"):
			return item.get("tool_input", true)
	return false
