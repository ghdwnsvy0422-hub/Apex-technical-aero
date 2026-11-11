extends GutTest

const Registry := preload("res://core/data_registry.gd")

const SHIPPED_TRACK := "res://data/tracks/aurora_speedway.json"


func _shipped() -> Dictionary:
	return Registry.read_json(SHIPPED_TRACK) as Dictionary


func _one_segment(segment: Dictionary) -> Dictionary:
	return {"segments": [segment]}


func _polyline_length(positions: Array[Vector3]) -> float:
	var total := 0.0
	for index: int in positions.size():
		total += positions[index].distance_to(positions[(index + 1) % positions.size()])
	return total


# --- segment geometry ------------------------------------------------------

func test_a_right_corner_turns_towards_positive_x() -> void:
	var layout := TrackLayout.from_track(
		_one_segment({"kind": "corner", "angle_deg": 90.0, "radius_m": 100.0})
	)
	assert_almost_eq(layout.end_position.x, 100.0, 0.001)
	assert_almost_eq(layout.end_position.z, -100.0, 0.001)
	assert_almost_eq(rad_to_deg(layout.end_heading_rad), 90.0, 0.001)


func test_a_left_corner_mirrors_the_right_corner() -> void:
	var layout := TrackLayout.from_track(
		_one_segment({"kind": "corner", "angle_deg": -90.0, "radius_m": 100.0})
	)
	assert_almost_eq(layout.end_position.x, -100.0, 0.001)
	assert_almost_eq(layout.end_position.z, -100.0, 0.001)
	assert_almost_eq(rad_to_deg(layout.end_heading_rad), -90.0, 0.001)


func test_a_straight_samples_at_the_requested_spacing() -> void:
	var layout := TrackLayout.from_track(
		_one_segment({"kind": "straight", "length_m": 100.0, "elevation_m": 5.0}), 10.0
	)
	assert_eq(layout.positions.size(), 10)
	assert_eq(layout.positions[0], Vector3.ZERO)
	assert_almost_eq(layout.end_position.z, -100.0, 0.001)
	assert_almost_eq(layout.end_position.y, 5.0, 0.001)


func test_a_chicane_returns_to_the_centreline() -> void:
	var layout := TrackLayout.from_track(
		_one_segment({"kind": "chicane", "length_m": 90.0, "offset_m": 12.0})
	)
	assert_almost_eq(layout.end_position.x, 0.0, 0.001)
	assert_almost_eq(layout.end_position.z, -90.0, 0.001)
	assert_almost_eq(rad_to_deg(layout.end_heading_rad), 0.0, 0.001)

	var widest := 0.0
	for point: Vector3 in layout.positions:
		widest = maxf(widest, absf(point.x))
	assert_between(widest, 10.0, 12.0, "chicane offset in metres")


func test_unknown_segments_are_skipped() -> void:
	var layout := TrackLayout.from_track(_one_segment({"kind": "loop", "length_m": 100.0}))
	assert_eq(layout.positions.size(), 0)
	assert_eq(layout.end_position, Vector3.ZERO)


# --- the shipped circuit ---------------------------------------------------

func test_shipped_track_returns_to_its_start_line() -> void:
	var layout := TrackLayout.from_track(_shipped())
	assert_lt(layout.closure_gap_m(), Registry.MAX_CLOSURE_GAP_M)
	assert_lt(layout.heading_error_deg(), 0.1)


func test_sampled_length_matches_the_segment_arithmetic() -> void:
	var track := _shipped()
	var expected := Registry.track_length_m(track)
	var sampled := _polyline_length(TrackLayout.from_track(track).positions)
	assert_almost_eq(sampled, expected, expected * 0.03)


# --- compiled curve --------------------------------------------------------

func test_compiled_curve_closes_on_itself() -> void:
	var curve := TrackCompiler.curve_from(_shipped())
	var start := curve.get_point_position(0)
	var last := curve.get_point_position(curve.point_count - 1)
	assert_lt(start.distance_to(last), CurveBuilder.POINT_SPACING * 1.5)


func test_compiled_curve_length_matches_the_track() -> void:
	var track := _shipped()
	var expected := Registry.track_length_m(track)
	assert_almost_eq(TrackCompiler.curve_from(track).get_baked_length(), expected, expected * 0.03)


func test_compiler_stitches_a_layout_that_drifts() -> void:
	var track := {
		"segments": [
			{"kind": "straight", "length_m": 400.0},
			{"kind": "corner", "angle_deg": 90.0, "radius_m": 100.0},
			{"kind": "straight", "length_m": 200.0},
			{"kind": "corner", "angle_deg": 90.0, "radius_m": 100.0},
			{"kind": "straight", "length_m": 100.0},
			{"kind": "corner", "angle_deg": 90.0, "radius_m": 100.0},
			{"kind": "straight", "length_m": 200.0},
			{"kind": "corner", "angle_deg": 90.0, "radius_m": 100.0},
		],
	}
	var layout := TrackLayout.from_track(track)
	assert_gt(layout.closure_gap_m(), 100.0, "this layout is deliberately open")

	var stitched := TrackCompiler.closed_positions(layout)
	assert_eq(stitched[0], layout.positions[0])
	assert_lt(
		stitched[stitched.size() - 1].distance_to(stitched[0]),
		CurveBuilder.POINT_SPACING * 1.5
	)


func test_banking_reaches_the_banked_corner_only() -> void:
	var curve := TrackCompiler.curve_from(_shipped())
	var steepest := 0.0
	var biggest_step := 0.0
	for index: int in curve.point_count:
		var tilt := curve.get_point_tilt(index)
		var next := curve.get_point_tilt((index + 1) % curve.point_count)
		steepest = maxf(steepest, absf(tilt))
		biggest_step = maxf(biggest_step, absf(next - tilt))

	assert_almost_eq(steepest, deg_to_rad(3.0), deg_to_rad(0.2))
	assert_lt(biggest_step, deg_to_rad(3.0) / 2.0)
	assert_almost_eq(curve.get_point_tilt(0), 0.0, 0.0001)


func test_compiled_track_carries_the_curve() -> void:
	var track := TrackCompiler.build(_shipped())
	assert_not_null(track.curve)
	assert_gt(track.curve.point_count, 100)
	track.free()
