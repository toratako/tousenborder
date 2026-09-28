class_name PackLoader
extends RefCounted
## Packs select standalone problems and attach chapter presentation to a session copy.


static func load_pack(source: ContentSource, path: String, problems: Dictionary) -> Dictionary:
	var result := read_document(source, path, ContentSchema.PACK)
	if not result.errors.is_empty():
		return { "pack": { }, "errors": result.errors }
	var pack: Dictionary = result.value
	pack.key = source.id + "/pack/" + pack.id
	pack.source_id = source.id
	pack.path = path
	var chapters: Array[Dictionary] = []
	var ids := { }
	var errors: PackedStringArray = []
	for relative in pack.chapters:
		if not ContentSource.valid_path(relative):
			errors.append(path + ": 不正な章の相対パス: " + relative)
			continue
		var chapter_path: String = path.get_base_dir().path_join(relative)
		var loaded := read_document(source, chapter_path, ContentSchema.CHAPTER)
		if not loaded.errors.is_empty():
			errors.append_array(loaded.errors)
			continue
		var chapter: Dictionary = loaded.value
		if ids.has(chapter.id):
			errors.append(chapter_path + ": 章IDが重複しています: " + chapter.id)
		ids[chapter.id] = true
		for id in chapter.problems:
			if not problems.has(id):
				errors.append(chapter_path + ": 問題が存在しません: " + id)
		chapters.append(chapter)
	pack.chapters = chapters
	return { "pack": pack if errors.is_empty() else { }, "errors": errors }


static func read_document(source: ContentSource, path: String, schema: String) -> Dictionary:
	if not source.files.has(path):
		return { "value": { }, "errors": PackedStringArray([path + ": JSONがありません。"]) }
	var parser := JSON.new()
	if parser.parse(source.files[path].get_string_from_utf8()) != OK:
		return {
			"value": { },
			"errors": PackedStringArray(
				["%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()]]
			),
		}
	var errors := ContentSchema.validate(parser.data, schema)
	for i in errors.size():
		errors[i] = path + ": " + errors[i]
	return { "value": parser.data, "errors": errors }
