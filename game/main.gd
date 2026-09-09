extends Node
## Boot entry point for every run mode.
##
## Stage 0.1 has no gameplay scenes yet, so this currently verifies the
## environment and reports it. Phase 1 replaces the placeholder branches with
## real scene routing.

const _TAG := "Main"


func _ready() -> void:
	if GameConfig.args.has("selfcheck"):
		_run_selfcheck()
		return

	match GameConfig.mode:
		GameConfig.Mode.DEDICATED_SERVER:
			Log.info(_TAG, "Dedicated server boot (port %d)" % GameConfig.server_port)
		GameConfig.Mode.SIMULATION:
			Log.info(_TAG, "Headless simulation boot")
			add_child(preload("res://tests/sim/physics_probe.gd").new())
		_:
			Log.info(_TAG, "Client boot")
			_start_client()


func _start_client() -> void:
	add_child(preload("res://client/test_drive.gd").new())

	if not GameConfig.args.has("capture"):
		return
	var capture: Node = preload("res://client/screen_capture.gd").new()
	capture.output_path = str(GameConfig.args["capture"])
	capture.delay_frames = int(GameConfig.args.get("capture-frames", 240))
	add_child(capture)


## Verifies the engine is configured the way the physics work assumes.
## Run with: godot --headless --path game -- --selfcheck
func _run_selfcheck() -> void:
	var failures: Array[String] = []

	var engine_name := str(ProjectSettings.get_setting("physics/3d/physics_engine", ""))
	if engine_name != "Jolt Physics":
		failures.append("physics engine is '%s', expected 'Jolt Physics'" % engine_name)

	if Engine.physics_ticks_per_second != 120:
		failures.append("physics tick is %d Hz, expected 120" % Engine.physics_ticks_per_second)

	var required_actions: Array[String] = [
		"throttle", "brake", "steer_left", "steer_right",
		"energy_boost", "pit_request", "camera_cycle",
		"look_back", "reset_car", "pause",
	]
	for action: String in required_actions:
		if not InputMap.has_action(action):
			failures.append("missing input action '%s'" % action)

	for message: String in DataRegistry.load_errors:
		failures.append("data: %s" % message)

	if failures.is_empty():
		Log.info(_TAG, "Selfcheck passed")
		get_tree().quit(0)
		return

	for failure: String in failures:
		Log.error(_TAG, "Selfcheck: %s" % failure)
	get_tree().quit(1)
