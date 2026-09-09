extends Node
## Logging autoload. Every subsystem logs through here so the dedicated
## server produces one greppable stream instead of scattered print() calls.

enum Level { DEBUG, INFO, WARN, ERROR }

var min_level: Level = Level.INFO

const _LEVEL_NAMES: Array[String] = ["DEBUG", "INFO", "WARN", "ERROR"]


func _ready() -> void:
	if OS.is_debug_build():
		min_level = Level.DEBUG


func debug(tag: String, message: String) -> void:
	_write(Level.DEBUG, tag, message)


func info(tag: String, message: String) -> void:
	_write(Level.INFO, tag, message)


func warn(tag: String, message: String) -> void:
	_write(Level.WARN, tag, message)


func error(tag: String, message: String) -> void:
	_write(Level.ERROR, tag, message)


func _write(level: Level, tag: String, message: String) -> void:
	if level < min_level:
		return
	var line := "[%s] %-6s %s: %s" % [
		_timestamp(), _LEVEL_NAMES[level], tag, message
	]
	if level >= Level.WARN:
		printerr(line)
	else:
		print(line)


func _timestamp() -> String:
	var t := Time.get_time_dict_from_system(true)
	return "%02d:%02d:%02d" % [t.hour, t.minute, t.second]
