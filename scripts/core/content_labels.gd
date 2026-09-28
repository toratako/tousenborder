class_name ContentLabels
extends RefCounted
## IDs have one presentation vocabulary; the library derives which choices exist.

const CATEGORIES := {"file": "ファイル", "process": "プロセス", "network": "ネットワーク", "web": "Web", "email": "メール", "account": "アカウント・認証", "package": "パッケージ"}
const DIFFICULTIES := {"unrated": "未評価", "beginner": "初級", "intermediate": "中級", "advanced": "上級"}
const METHODS := {"initial": "初期情報のみ", "references": "資料の照合", "tools": "ツールあり", "external": "外部照会あり"}
const PLATFORMS := {"windows": "Windows", "linux": "Linux", "common": "環境共通"}
const KINDS := {"tools": "Tool", "references": "Reference", "external_references": "External Reference"}

static func actions() -> Array[Dictionary]:
	return [{"id": "allow", "label": "ALLOW", "color": "8ba879"}, {"id": "block", "label": "BLOCK", "color": "bc6452"}]

static func category(item: Dictionary) -> String:
	return item.get("category_label", CATEGORIES.get(item.category, item.category))
