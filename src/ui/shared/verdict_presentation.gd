extends RefCounted
## 判定直後と履歴の振り返りで、判定文と調査の注意条件を共有する。


static func summary(record: Dictionary, feedback: Dictionary, labels: Dictionary) -> String:
	var chosen: String = labels.get(record.verdict, record.verdict)
	chosen += " ／ 許可" if record.verdict == "allow" else " ／ 遮断" if record.verdict == "block" else ""
	if not feedback.get("show_expected", true):
		return "あなたは %s を選びました。" % chosen
	if record.correct:
		return "%sで正しく判断できました。" % chosen
	return (
		("この対象は許可できました。" if record.ground_truth == "allow" else "この対象は遮断する必要がありました。")
		+ "\nあなたは %s を選びました。" % chosen
	)


static func unsafe_investigation(record: Dictionary) -> bool:
	return record.observations.any(
		func(observation):
			return observation.get("ok", false) and not observation.get("skipped", false) and not observation.get("correct_usage", true)
	)
