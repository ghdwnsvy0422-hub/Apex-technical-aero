extends GutTest

const Registry := preload("res://core/data_registry.gd")

const SHIPPED_TRACK := "res://data/tracks/aurora_speedway.json"


func _shipped() -> Dictionary:
	return Registry.read_json(SHIPPED_TRACK) as Dictionary


func _minimal_track(overrides: Dictionary = {}) -> Dictionary:
	var track: Dictionary = {
		"schema_version": Registry.SCHEMA_VERSION,
		"id": "test_track",
		"name": "Test Track",
		"type": "technical",
		"width_m": 14.0,
		"race_laps": 6,
		"sector_count": 3,
		"segments": [
			{"kind": "straight", "length_m": 400.0},
			{"kind": "corner", "angle_deg": 180.0, "radius_m": 120.0},
			{"kind": "straight", "length_m": 400.0},
			{"kind": "corner", "angle_deg": 180.0, "radius_m": 120.0},
		],
		"pit": {"entry_segment": 3, "exit_segment": 0, "lane_speed_kph": 80.0},
	}
	track.merge(overrides, true)
	return track


# --- shipped content -------------------------------------------------------

func test_shipped_track_is_valid() -> void:
	assert_eq(
		Registry.validate_track(_shipped()),
		PackedStringArray(),
		"aurora_speedway.json should validate clean"
	)


func test_shipped_track_closes() -> void:
	assert_almost_eq(Registry.track_turn_degrees(_shipped()), 360.0, 0.001)
	assert_true(Registry.track_closes(_shipped()), "shipped centreline should close")


func test_shipped_track_length_is_plausible() -> void:
	assert_between(Registry.track_length_m(_shipped()), 2000.0, 7000.0, "track length in metres")


func test_track_paths_finds_shipped_track() -> void:
	assert_has(Array(Registry.track_paths()), SHIPPED_TRACK)


func test_registry_loads_shipped_track() -> void:
	assert_false(DataRegistry.get_track("aurora_speedway").is_empty())
	assert_true(DataRegistry.get_track("no_such_track").is_empty())


# --- geometry --------------------------------------------------------------

func test_length_sums_straights_arcs_and_chicanes() -> void:
	var track: Dictionary = {
		"segments": [
			{"kind": "straight", "length_m": 250.0},
			{"kind": "corner", "angle_deg": 90.0, "radius_m": 100.0},
			{"kind": "chicane", "length_m": 90.0, "offset_m": 12.0},
		],
	}
	assert_almost_eq(Registry.track_length_m(track), 497.0796, 0.01)


func test_turn_total_counts_direction() -> void:
	var track: Dictionary = {
		"segments": [
			{"kind": "corner", "angle_deg": 90.0, "radius_m": 100.0},
			{"kind": "corner", "angle_deg": -30.0, "radius_m": 80.0},
		],
	}
	assert_almost_eq(Registry.track_turn_degrees(track), 60.0, 0.001)


# --- validation rules ------------------------------------------------------

func test_open_layout_is_rejected() -> void:
	var track := _minimal_track({
		"segments": [
			{"kind": "straight", "length_m": 400.0},
			{"kind": "corner", "angle_deg": 90.0, "radius_m": 120.0},
			{"kind": "straight", "length_m": 400.0},
		],
		"pit": {"entry_segment": 2, "exit_segment": 0, "lane_speed_kph": 80.0},
	})
	assert_eq(Registry.validate_track(track).size(), 1, "one closure error")


func test_unknown_segment_kind_is_rejected() -> void:
	var track := _minimal_track()
	(track["segments"] as Array).append({"kind": "loop", "length_m": 10.0})
	assert_eq(Registry.validate_track(track).size(), 1)


func test_corner_needs_positive_radius() -> void:
	var track := _minimal_track()
	((track["segments"] as Array)[1] as Dictionary)["radius_m"] = 0.0
	assert_eq(Registry.validate_track(track).size(), 1)


func test_excessive_banking_is_rejected() -> void:
	var track := _minimal_track()
	((track["segments"] as Array)[1] as Dictionary)["banking_deg"] = 40.0
	assert_eq(Registry.validate_track(track).size(), 1)


func test_pit_segment_outside_range_is_rejected() -> void:
	var track := _minimal_track({
		"pit": {"entry_segment": 9, "exit_segment": 0, "lane_speed_kph": 80.0},
	})
	assert_eq(Registry.validate_track(track).size(), 1)


func test_pit_entry_and_exit_must_differ() -> void:
	var track := _minimal_track({
		"pit": {"entry_segment": 2, "exit_segment": 2, "lane_speed_kph": 80.0},
	})
	assert_eq(Registry.validate_track(track).size(), 1)


func test_unknown_track_type_is_rejected() -> void:
	assert_eq(Registry.validate_track(_minimal_track({"type": "rally"})).size(), 1)


func test_schema_version_must_match() -> void:
	assert_eq(Registry.validate_track(_minimal_track({"schema_version": 99})).size(), 1)


func test_missing_file_is_reported() -> void:
	assert_eq(Registry.validate_track(null).size(), 1)
