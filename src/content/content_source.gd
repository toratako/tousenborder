class_name ContentSource
extends RefCounted
## Storage boundary. Consumers see relative JSON paths and bytes, never res:// overrides.
const MAX_FILES := 512
const MAX_FILE_BYTES := 1024 * 1024
const MAX_TOTAL_BYTES := 8 * 1024 * 1024
const MAX_ARCHIVE_BYTES := 16 * 1024 * 1024
var id := ""
var files: Dictionary = { }
var error := ""
var payload := PackedByteArray()
var extension := ""
var _total := 0


static func valid_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or "\\" in path or ":" in path:
		return false
	for part in path.split("/"):
		if part in ["", ".", ".."]:
			return false
	return true


static func directory(root: String, source_id := "builtin") -> ContentSource:
	var source := ContentSource.new()
	source.id = source_id
	if not DirAccess.dir_exists_absolute(root):
		source.error = "教材ディレクトリがありません: " + root
		return source
	for folder in ["problems", "packs"]:
		if DirAccess.dir_exists_absolute(root.path_join(folder)):
			source._scan(root, folder)
	return source


func _scan(root: String, relative: String) -> void:
	if not error.is_empty():
		return
	var directory := DirAccess.open(root.path_join(relative))
	if directory == null:
		error = "ディレクトリを読めません: " + relative
		return
	var names := directory.get_files()
	names.sort()
	for name in names:
		if name.get_extension() != "json" or directory.is_link(name):
			continue
		var path := relative.path_join(name)
		var file := FileAccess.open(root.path_join(path), FileAccess.READ)
		if file == null or file.get_length() > MAX_FILE_BYTES:
			error = "JSONを読めないか、容量上限を超えています: " + path
			return
		_add(path, file.get_buffer(file.get_length()))
		if not error.is_empty():
			return
	var directories := directory.get_directories()
	directories.sort()
	for name in directories:
		if not name.begins_with(".") and not directory.is_link(name):
			_scan(root, relative.path_join(name))


func _add(path: String, bytes: PackedByteArray) -> void:
	if not valid_path(path) or files.has(path):
		error = "重複または不正な相対パス: " + path
	elif (
		bytes.size() > MAX_FILE_BYTES or _total + bytes.size() > MAX_TOTAL_BYTES
		or files.size() >= MAX_FILES
	):
		error = "教材の件数・容量上限を超えています。"
	else:
		files[path] = bytes
		_total += bytes.size()


static func open_file(path: String) -> ContentSource:
	var source := ContentSource.new()
	source.extension = path.get_extension().to_lower()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_ARCHIVE_BYTES:
		source.error = "教材ファイルを読めないか、容量上限を超えています。"
		return source
	source.payload = file.get_buffer(file.get_length())
	file.close()
	source.id = source.extension + ":" + digest(source.payload)
	if source.extension == "json":
		source._add("problems/problem.json", source.payload)
	elif source.extension == "zip":
		var entries := source._zip_entries()
		if not source.error.is_empty():
			return source
		# Read the exact bytes that passed preflight, even if the selected file changes.
		var snapshot := FileAccess.create_temp(FileAccess.READ_WRITE, "packets-content-", "zip")
		if snapshot == null:
			source.error = "ZIPの読込用ファイルを作成できません。"
			return source
		snapshot.store_buffer(source.payload)
		snapshot.flush()
		var reader := ZIPReader.new()
		if snapshot.get_error() != OK or reader.open(snapshot.get_path()) != OK:
			source.error = "ZIPを開けません。"
			return source
		for entry in entries:
			var bytes := reader.read_file(entry.path, true)
			if bytes.size() != entry.size:
				source.error = "ZIPの内容がサイズ宣言と一致しません: " + entry.path
				break
			source._add(entry.path, bytes)
			if not source.error.is_empty():
				break
		reader.close()
	else:
		source.error = "JSONまたはZIPを指定してください。"
	return source


static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _zip_entries() -> Array[Dictionary]:
	# Inspect the directory before ZIPReader allocates uncompressed file contents.
	var entries: Array[Dictionary] = []
	var end := -1
	for offset in range(payload.size() - 22, maxi(-1, payload.size() - 65558), -1):
		if (
			payload.decode_u32(offset) == 0x06054b50
			and offset + 22 + payload.decode_u16(offset + 20) == payload.size()
		):
			end = offset
			break
	if end < 0:
		error = "ZIPの索引が壊れています。"
		return entries
	var count := payload.decode_u16(end + 10)
	var position := int(payload.decode_u32(end + 16))
	var directory_size := int(payload.decode_u32(end + 12))
	if (
		payload.decode_u16(end + 4) != 0 or payload.decode_u16(end + 6) != 0
		or count != payload.decode_u16(end + 8)
		or count > MAX_FILES or position + directory_size != end
	):
		error = "分割ZIP・ZIP64または件数上限を超えたZIPには対応していません。"
		return entries
	var names := { }
	var total := 0
	for index in count:
		if position + 46 > end or payload.decode_u32(position) != 0x02014b50:
			error = "ZIPの索引が壊れています。"
			return []
		var name_size := payload.decode_u16(position + 28)
		var next := position + 46 + name_size + payload.decode_u16(position + 30) + payload.decode_u16(
			position + 32
		)
		if next > end:
			error = "ZIPの索引が途中で切れています。"
			return []
		var path := payload.slice(position + 46, position + 46 + name_size).get_string_from_utf8()
		var directory := path.ends_with("/")
		var normalized := path.trim_suffix("/") if directory else path
		var size := int(payload.decode_u32(position + 24))
		var compressed := int(payload.decode_u32(position + 20))
		var method := payload.decode_u16(position + 10)
		var flags := payload.decode_u16(position + 8)
		var local := int(payload.decode_u32(position + 42))
		var mode := (payload.decode_u32(position + 38) >> 16) & 0xf000
		if (
			not valid_path(normalized) or names.has(normalized.to_lower())
			or (not directory and path.get_extension() != "json")
		):
			error = "ZIPには重複のない相対パスのJSONだけを配置してください: " + path
			return []
		if (
			flags & 1 or method not in [0, 8] or mode not in [0, 0x4000, 0x8000]
			or payload.decode_u16(position + 34) != 0
		):
			error = "暗号化・特殊ファイル・未対応の圧縮方式です: " + path
			return []
		if size > MAX_FILE_BYTES or total + size > MAX_TOTAL_BYTES or compressed > MAX_ARCHIVE_BYTES:
			error = "ZIP内のJSONが容量上限を超えています: " + path
			return []
		if local + 30 > position or payload.decode_u32(local) != 0x04034b50:
			error = "ZIPのファイル位置が不正です: " + path
			return []
		var local_name_size := payload.decode_u16(local + 26)
		var data_start := local + 30 + local_name_size + payload.decode_u16(local + 28)
		if (
			data_start + compressed > int(payload.decode_u32(end + 16))
			or payload.slice(local + 30, local + 30 + local_name_size).get_string_from_utf8() != path
			or payload.decode_u16(local + 8) != method or payload.decode_u16(local + 6) != flags
		):
			error = "ZIPのファイルと索引が一致しません: " + path
			return []
		names[normalized.to_lower()] = true
		total += size
		if not directory:
			entries.append({ "path": path, "size": size })
		position = next
	if position != end:
		error = "ZIPの索引サイズが一致しません。"
	return entries
