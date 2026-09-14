extends RefCounted
## 使用中のエンジンと同梱フォントから、配布物に対応する表記を集める。

static func sections() -> Array[Dictionary]:
	var copyrights: PackedStringArray = []
	for component in Engine.get_copyright_info():
		copyrights.append(component.name)
		for part in component.parts:
			copyrights.append("\n".join(part.copyright))
			copyrights.append("License: " + part.license)
			copyrights.append("Files:\n" + "\n".join(part.files))
		copyrights.append("")
	var license_texts: PackedStringArray = []
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name in names:
		license_texts.append("%s\n\n%s" % [name, licenses[name]])
	return [
		{"title": "Godot Engine", "body": "Godot Engine %s\nhttps://godotengine.org/license/\n\n%s" % [Engine.get_version_info().string, Engine.get_license_text()]},
		{"title": "フォント", "body": FileAccess.get_file_as_string("res://assets/fonts/LICENSE")},
		{"title": "第三者の著作権", "body": "Godotに含まれるコンポーネントの著作権表記\n\n" + "\n".join(copyrights)},
		{"title": "第三者のライセンス", "body": "Godotに含まれるコンポーネントのライセンス全文\n\n" + "\n\n".join(license_texts)},
	]
