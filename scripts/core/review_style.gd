class_name ReviewStyle
extends RefCounted
## 判定時の記録から今回の審査スタイルを選ぶ。人格・恒常的な能力は評価しない。

const HIGH_ACCURACY := 0.8
const MEDIUM_ACCURACY := 0.5
const HIGH_EVIDENCE := 0.8

# 各行は正解率の高・中・低。確認率は問題別の平均ではなく証拠数で集計する。
const THOROUGH := [
	{"id": "analyst", "label": "根拠を揃える分析官", "message": "調査も判断も着実。次は難しい案件に挑戦しよう。"},
	{"id": "investigator", "label": "照合を磨く調査官", "message": "資料を集める姿勢が強み。判断を分けた情報を振り返ろう。"},
	{"id": "explorer", "label": "粘り強い探究者", "message": "調査の土台はできています。監査所見で、証拠と結論のつながりを確認しよう。"},
]
const LIMITED := [
	{"id": "intuitive", "label": "勘どころをつかむ審査官", "message": "正しい判断ができています。次は証拠も揃えて、判断を裏付けよう。"},
	{"id": "challenger", "label": "判断を試す挑戦者", "message": "判断のポイントをつかみ始めています。迷った場面では資料との照合を試そう。"},
	{"id": "trainee", "label": "第一歩を踏み出す研修官", "message": "まずは一問、監査所見を参考に、調査から判断まで辿ってみよう。"},
]
const BASIC := {"id": "basic", "label": "基礎判断チャレンジャー", "message": "監査所見で判断のポイントを振り返り、次は調査が必要な案件にも挑戦しよう。"}

static func classify(records: Array[Dictionary]) -> Dictionary:
	if records.is_empty():
		return {}
	var correct_count := 0
	var required_count := 0
	var confirmed_count := 0
	for record in records:
		if record.correct:
			correct_count += 1
		required_count += record.required_evidence_count
		confirmed_count += record.confirmed_evidence_count
	if required_count == 0:
		return BASIC.duplicate(true)
	var accuracy := float(correct_count) / records.size()
	var evidence_rate := float(confirmed_count) / required_count
	var band := 0 if accuracy >= HIGH_ACCURACY else (1 if accuracy >= MEDIUM_ACCURACY else 2)
	var styles: Array = THOROUGH if evidence_rate >= HIGH_EVIDENCE else LIMITED
	return styles[band].duplicate(true)
