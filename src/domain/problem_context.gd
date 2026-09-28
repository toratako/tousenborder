class_name ProblemContext
extends RefCounted
## Identity and environment rules for a validated problem; independent of loading and execution.


static func identity(item: Dictionary) -> String:
	return item.get("key", item.id)


static func investigation_environment(target: Dictionary) -> String:
	var platform: String = target.platform
	return "linux" if platform == "common" else platform


static func supports_target(tool: Dictionary, target: Dictionary) -> bool:
	var environments: Array = tool.get("environments", [])
	return environments.is_empty() or investigation_environment(target) in environments
