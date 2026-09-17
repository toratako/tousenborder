class_name ContentSchema
extends RefCounted
## 同梱JSON Schemaで構造を検証する。使用していないSchema機能は黙って無視しない。

const KEYWORDS := ["$schema", "title", "description", "$defs", "$ref", "type", "const", "enum",
	"properties", "required", "additionalProperties", "items", "minLength", "minItems", "minProperties",
	"minimum", "maximum", "pattern", "uniqueItems", "allOf", "anyOf", "if", "then", "else"]
const PACK := "res://data/schemas/pack.schema.json"
const PROBLEM := "res://data/schemas/problem.schema.json"

static func read_schema(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func validate(value: Variant, path: String) -> PackedStringArray:
	return check(value, read_schema(path))

static func check(value: Variant, schema: Variant) -> PackedStringArray:
	var errors: PackedStringArray = []
	_schema_errors(schema, schema, "$schema", errors)
	if errors.is_empty():
		_check(value, schema, schema, "$", errors, 0)
	return errors

static func _resolve(root: Variant, ref: String) -> Variant:
	if not ref.begins_with("#/"):
		return null
	var current: Variant = root
	for part in ref.substr(2).split("/"):
		var key := part.replace("~1", "/").replace("~0", "~")
		if not current is Dictionary or not current.has(key):
			return null
		current = current[key]
	return current

static func _schema_errors(schema: Variant, root: Variant, path: String, errors: PackedStringArray) -> void:
	if schema is bool:
		return
	if not schema is Dictionary:
		errors.append(path + ": Schema must be an object or boolean")
		return
	for key in schema:
		if key not in KEYWORDS:
			errors.append(path + ": unsupported Schema keyword " + str(key))
	if schema.has("$ref"):
		if not schema["$ref"] is String or not schema["$ref"].begins_with("#/$defs/") or _resolve(root, schema["$ref"]) == null:
			errors.append(path + ": invalid local $ref")
		else:
			var referenced: Variant = _resolve(root, schema["$ref"])
			if not referenced is Dictionary and not referenced is bool:
				errors.append(path + ": $ref must point to a Schema")
	if schema.has("type"):
		var types: Array = schema.type if schema.type is Array else [schema.type]
		if types.is_empty() or not types.all(func(type): return type in ["object", "array", "string", "boolean", "null", "number", "integer"]):
			errors.append(path + ": invalid type")
	if schema.has("enum") and (not schema.enum is Array or schema.enum.is_empty()):
		errors.append(path + ": enum must be a nonempty array")
	if schema.has("required"):
		if not schema.required is Array or not schema.required.all(func(key): return key is String):
			errors.append(path + ": required must be a string array")
	for key in ["minLength", "minItems", "minProperties"]:
		if schema.has(key) and (not _matches_type(schema[key], "integer") or schema[key] < 0):
			errors.append(path + ": " + key + " must be a nonnegative integer")
	for key in ["minimum", "maximum"]:
		if schema.has(key) and not _matches_type(schema[key], "number"):
			errors.append(path + ": " + key + " must be a finite number")
	if schema.has("uniqueItems") and not schema.uniqueItems is bool:
		errors.append(path + ": uniqueItems must be a boolean")
	if schema.has("pattern"):
		var expression := RegEx.new()
		if not schema.pattern is String or expression.compile(schema.pattern) != OK:
			errors.append(path + ": invalid pattern")
	for key in ["properties", "$defs"]:
		if schema.has(key):
			if not schema[key] is Dictionary:
				errors.append(path + ": " + key + " must be an object")
				continue
			for name in schema[key]:
				_schema_errors(schema[key][name], root, path + "/" + key + "/" + name, errors)
	for key in ["items", "additionalProperties", "if", "then", "else"]:
		if schema.has(key):
			_schema_errors(schema[key], root, path + "/" + key, errors)
	for key in ["allOf", "anyOf"]:
		if schema.has(key):
			if not schema[key] is Array or schema[key].is_empty():
				errors.append(path + ": " + key + " must be a nonempty array")
				continue
			for child in schema[key]:
				_schema_errors(child, root, path + "/" + key, errors)

static func _matches_type(value: Variant, type: String) -> bool:
	match type:
		"object": return value is Dictionary
		"array": return value is Array
		"string": return value is String
		"boolean": return value is bool
		"null": return value == null
		"number": return (value is int or value is float) and is_finite(float(value))
		"integer": return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))
	return false

static func _equal(a: Variant, b: Variant) -> bool:
	# JSON equality distinguishes true from 1, but treats 1 and 1.0 as equal.
	if (a is int or a is float) and (b is int or b is float):
		return a == b
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key], b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not _equal(a[index], b[index]): return false
		return true
	return a == b

static func _check(value: Variant, schema: Variant, root: Variant, path: String, errors: PackedStringArray, depth: int) -> void:
	if depth > 128:
		errors.append(path + ": Schema nesting limit exceeded")
		return
	if schema is bool:
		if not schema: errors.append(path + ": forbidden value")
		return
	if schema.has("$ref"):
		_check(value, _resolve(root, schema["$ref"]), root, path, errors, depth + 1)
	if schema.has("type"):
		var types: Array = schema.type if schema.type is Array else [schema.type]
		if not types.any(func(type): return _matches_type(value, type)):
			errors.append(path + ": expected " + str(schema.type))
			return
	if schema.has("const") and not _equal(value, schema["const"]):
		errors.append(path + ": expected constant " + str(schema["const"]))
	if schema.has("enum") and not schema.enum.any(func(option): return _equal(value, option)):
		errors.append(path + ": value is not in enum")
	for child in schema.get("allOf", []):
		_check(value, child, root, path, errors, depth + 1)
	if schema.has("anyOf"):
		var matched := false
		for child in schema.anyOf:
			var branch_errors: PackedStringArray = []
			_check(value, child, root, path, branch_errors, depth + 1)
			matched = matched or branch_errors.is_empty()
		if not matched: errors.append(path + ": no anyOf branch matched")
	if schema.has("if"):
		var condition_errors: PackedStringArray = []
		_check(value, schema["if"], root, path, condition_errors, depth + 1)
		var branch := "then" if condition_errors.is_empty() else "else"
		if schema.has(branch): _check(value, schema[branch], root, path, errors, depth + 1)
	if value is Dictionary:
		for key in schema.get("required", []):
			if not value.has(key): errors.append(path + ": missing " + key)
		if value.size() < schema.get("minProperties", 0): errors.append(path + ": too few properties")
		var properties: Dictionary = schema.get("properties", {})
		for key in value:
			var child: Variant = properties.get(key, schema.get("additionalProperties", true))
			_check(value[key], child, root, path + "/" + str(key), errors, depth + 1)
	if value is Array:
		if value.size() < schema.get("minItems", 0): errors.append(path + ": too few items")
		for index in value.size():
			_check(value[index], schema.get("items", true), root, path + "/" + str(index), errors, depth + 1)
			if schema.get("uniqueItems", false):
				for previous in index:
					if _equal(value[index], value[previous]): errors.append(path + ": duplicate item")
	if value is String:
		if value.length() < schema.get("minLength", 0): errors.append(path + ": string is too short")
		if schema.has("pattern"):
			var expression := RegEx.new()
			expression.compile(schema.pattern)
			if expression.search(value) == null: errors.append(path + ": pattern mismatch")
	if value is int or value is float:
		if schema.has("minimum") and value < schema.minimum: errors.append(path + ": below minimum")
		if schema.has("maximum") and value > schema.maximum: errors.append(path + ": above maximum")
