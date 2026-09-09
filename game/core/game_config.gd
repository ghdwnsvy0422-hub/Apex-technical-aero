extends Node
## Run-mode and build information autoload.
##
## The same project ships as the player client, the authoritative dedicated
## server, and the headless simulation harness. Everything downstream branches
## on `mode`, so it is resolved exactly once, here, at boot.

enum Mode {
	CLIENT,
	DEDICATED_SERVER,
	SIMULATION,
}

const VERSION := "0.1.0-dev"
const DEFAULT_SERVER_PORT := 27015

var mode: Mode = Mode.CLIENT
var server_port: int = DEFAULT_SERVER_PORT
var physics_tick_hz: int = 120

## Extra `--key=value` user args, kept for subsystems that need them.
var args: Dictionary = {}


func _ready() -> void:
	args = parse_args(OS.get_cmdline_user_args())
	physics_tick_hz = Engine.physics_ticks_per_second
	mode = resolve_mode(args, OS.has_feature("dedicated_server"))
	server_port = resolve_port(args)
	Log.info("Boot", "Apex %s | mode=%s | physics=%dHz | %s" % [
		VERSION, mode_name(), physics_tick_hz, _physics_engine_name()
	])


func is_server() -> bool:
	return mode == Mode.DEDICATED_SERVER


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func mode_name() -> String:
	return Mode.keys()[mode]


## Parses `--flag` and `--key=value` into a dictionary. Flags become `true`,
## values stay strings. Leading dashes are stripped so `-x` and `--x` are equal.
static func parse_args(raw: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	for arg: String in raw:
		var clean := arg.lstrip("-")
		if clean.is_empty():
			continue
		if clean.contains("="):
			var pair := clean.split("=", true, 1)
			parsed[pair[0]] = pair[1]
		else:
			parsed[clean] = true
	return parsed


## An explicit flag always wins over the build feature so a dedicated-server
## export can still be launched as a sim harness for debugging.
static func resolve_mode(parsed: Dictionary, dedicated_build: bool) -> Mode:
	if parsed.has("server"):
		return Mode.DEDICATED_SERVER
	if parsed.has("sim"):
		return Mode.SIMULATION
	if dedicated_build:
		return Mode.DEDICATED_SERVER
	return Mode.CLIENT


static func resolve_port(parsed: Dictionary) -> int:
	var raw: Variant = parsed.get("port", DEFAULT_SERVER_PORT)
	var port := int(raw)
	if port <= 0 or port > 65535:
		return DEFAULT_SERVER_PORT
	return port


func _physics_engine_name() -> String:
	return str(ProjectSettings.get_setting("physics/3d/physics_engine", "unknown"))
