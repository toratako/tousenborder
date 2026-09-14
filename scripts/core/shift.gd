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
var time_limit_seconds := 0
var remaining_seconds := 0.0
var timed_out := false

func start(items: Array[Dictionary], limit_seconds: int = 0) -> void:
	cases = items.duplicate(true)
	time_limit_seconds = maxi(0, limit_seconds)
	remaining_seconds = float(time_limit_seconds)
	timed_out = false
	index = 0
	records.clear()
	observations.clear()
	judged = false
	changed.emit()

func current() -> Dictionary:
	return {} if finished() else cases[index]

func finished() -> bool:
	return timed_out or index >= cases.size()

func tick(delta: float) -> void:
	if finished() or judged or time_limit_seconds == 0 or not is_finite(delta) or delta <= 0:
		return
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	if remaining_seconds == 0:
		timed_out = true
		changed.emit()

func inspect(tool: Dictionary) -> Dictionary:
	if finished() or judged:
		return {"ok": false, "output": "この案件の審査は終了しています。"}
	var result := runner.run(tool, current())
	observations.append({"tool": tool.label, "ok": result.ok, "output": result.output})
	changed.emit()
	return result

func decide(verdict: String) -> bool:
	if finished() or judged or not verdict in ["approve", "deny"]:
		return false
	judged = true
	records.append({"id": current().id, "title": current().title, "verdict": verdict,
		"correct": verdict == current().expected, "expected": current().expected,
		"explanation": current().explanation, "observations": observations.duplicate(true)})
	changed.emit()
	return true

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
