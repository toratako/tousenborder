class_name ContentImportStore
extends RefCounted
## Persists only an already validated import. Filenames are content digests.
var directory: String
var error := ""


func _init(path := "user://content") -> void:
	directory = path


func sources() -> Array[ContentSource]:
	var result: Array[ContentSource] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return result
	var names := dir.get_files()
	names.sort()
	for name in names:
		if name.get_extension() in ["zip", "json"]:
			result.append(ContentSource.open_file(directory.path_join(name)))
	return result


func save(source: ContentSource) -> bool:
	error = ""
	if source.extension not in ["zip", "json"] or source.payload.is_empty():
		error = "保存できる教材ではありません。"
		return false
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		error = "教材の保存先を作成できません。"
		return false
	var digest := ContentSource.digest(source.payload)
	var path := directory.path_join(digest + "." + source.extension)
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == digest:
		return true
	var temporary := path + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error = "教材を保存できません。"
		return false
	file.store_buffer(source.payload)
	file.flush()
	var failed := file.get_error() != OK
	file.close()
	if (
		failed or FileAccess.get_sha256(temporary) != digest
		or DirAccess.rename_absolute(temporary, path) != OK
	):
		DirAccess.remove_absolute(temporary)
		error = "教材の保存を完了できません。"
		return false
	return true
