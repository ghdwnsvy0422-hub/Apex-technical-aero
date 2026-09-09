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
	args = _parse_user_args()
	physics_tick_hz = Engine.physics_ticks_per_second
	mode = _resolve_mode()
	Log.info("Boot", "Apex %s | mode=%s | physics=%dHz | %s" % [
		VERSION, mode_name(), physics_tick_hz, _physics_engine_name()
	])


func is_server() -> bool:
	return mode == Mode.DEDICATED_SERVER


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func mode_name() -> String:
	return Mode.keys()[mode]


func _resolve_mode() -> Mode:
	if args.has("server"):
		server_port = int(args.get("port", DEFAULT_SERVER_PORT))
		return Mode.DEDICATED_SERVER
	if args.has("sim"):
		return Mode.SIMULATION
	if OS.has_feature("dedicated_server"):
		return Mode.DEDICATED_SERVER
	return Mode.CLIENT


func _parse_user_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var clean := arg.lstrip("-")
		if clean.contains("="):
			var pair := clean.split("=", true, 1)
			parsed[pair[0]] = pair[1]
		else:
			parsed[clean] = true
	return parsed


func _physics_engine_name() -> String:
	return str(ProjectSettings.get_setting("physics/3d/physics_engine", "unknown"))
