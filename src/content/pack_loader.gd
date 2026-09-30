class_name PackLoader
extends RefCounted
## Packs order or sample standalone problems without modifying their definitions.


static func load_pack(source: ContentSource, path: String, problems: Dictionary) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(source.files[path].get_string_from_utf8()) != OK:
		return {
			"pack": { },
			"errors": PackedStringArray(
				["%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()]]
			),
		}
	var errors := ContentSchema.validate(parser.data, ContentSchema.PACK)
	for i in errors.size():
		errors[i] = path + ": " + errors[i]
	if not errors.is_empty():
		return { "pack": { }, "errors": errors }
	var pack: Dictionary = parser.data
	for id in pack.problems:
		if not problems.has(id):
			errors.append(path + ": 問題が存在しません: " + id)
	if not errors.is_empty():
		return { "pack": { }, "errors": errors }
	if pack.has("sampling"):
		var seen := { }
		for id in pack.problems:
			seen[id] = true
		var requested := int(pack.sampling.count)
		if requested > seen.size():
			errors.append(
				"%s: sampling.count: 指定は%d問ですが、候補は%d問です。"
				% [path, requested, seen.size()]
			)
	if not errors.is_empty():
		return { "pack": { }, "errors": errors }
	pack.key = source.id + "/pack/" + pack.id
	pack.source_id = source.id
	pack.path = path
	return { "pack": pack, "errors": errors }
