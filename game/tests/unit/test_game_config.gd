extends GutTest
## Launch-argument parsing decides whether a process becomes the client, the
## authoritative server, or the sim harness. A silent misparse would start the
## wrong one, so the resolution rules are pinned here.

const GameConfigScript := preload("res://core/game_config.gd")


func test_bare_flag_becomes_true() -> void:
	var parsed: Dictionary = GameConfigScript.parse_args(PackedStringArray(["--server"]))
	assert_eq(parsed.get("server"), true)


func test_key_value_keeps_string_value() -> void:
	var parsed: Dictionary = GameConfigScript.parse_args(PackedStringArray(["--port=27016"]))
	assert_eq(parsed.get("port"), "27016")


func test_value_containing_equals_is_not_split_twice() -> void:
	var parsed: Dictionary = GameConfigScript.parse_args(PackedStringArray(["--tag=a=b"]))
	assert_eq(parsed.get("tag"), "a=b")


func test_single_and_double_dash_are_equivalent() -> void:
	var single: Dictionary = GameConfigScript.parse_args(PackedStringArray(["-sim"]))
	var double: Dictionary = GameConfigScript.parse_args(PackedStringArray(["--sim"]))
	assert_eq(single, double)


func test_empty_and_dash_only_args_are_ignored() -> void:
	var parsed: Dictionary = GameConfigScript.parse_args(PackedStringArray(["--", ""]))
	assert_eq(parsed.size(), 0)


func test_defaults_to_client() -> void:
	assert_eq(
		GameConfigScript.resolve_mode({}, false),
		GameConfigScript.Mode.CLIENT
	)


func test_server_flag_selects_dedicated_server() -> void:
	assert_eq(
		GameConfigScript.resolve_mode({"server": true}, false),
		GameConfigScript.Mode.DEDICATED_SERVER
	)


func test_sim_flag_selects_simulation() -> void:
	assert_eq(
		GameConfigScript.resolve_mode({"sim": true}, false),
		GameConfigScript.Mode.SIMULATION
	)


func test_dedicated_build_defaults_to_server() -> void:
	assert_eq(
		GameConfigScript.resolve_mode({}, true),
		GameConfigScript.Mode.DEDICATED_SERVER
	)


func test_sim_flag_overrides_dedicated_build() -> void:
	assert_eq(
		GameConfigScript.resolve_mode({"sim": true}, true),
		GameConfigScript.Mode.SIMULATION
	)


func test_port_defaults_when_absent() -> void:
	assert_eq(
		GameConfigScript.resolve_port({}),
		GameConfigScript.DEFAULT_SERVER_PORT
	)


func test_port_parsed_from_string() -> void:
	assert_eq(GameConfigScript.resolve_port({"port": "27016"}), 27016)


func test_out_of_range_port_falls_back_to_default() -> void:
	assert_eq(
		GameConfigScript.resolve_port({"port": "70000"}),
		GameConfigScript.DEFAULT_SERVER_PORT
	)
	assert_eq(
		GameConfigScript.resolve_port({"port": "0"}),
		GameConfigScript.DEFAULT_SERVER_PORT
	)
