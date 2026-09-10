extends GutTest

const Registry := preload("res://core/data_registry.gd")

const SHIPPED_TRACK := "res://data/tracks/aurora_speedway.json"
const HALF_WIDTH: float = 7.5
const TURN_ONE_ENTRY_M: float = 830.0
const TURN_ONE_APEX_M: float = 944.0
const TURN_ONE_EXIT_M: float = 1060.0

var _track: Dictionary
var _curve: Curve3D
var _line: RacingLine
var _centreline: RacingLine


func before_all() -> void:
	_track = Registry.read_json(SHIPPED_TRACK) as Dictionary
	_curve = TrackCompiler.curve_from(_track)
	_line = RacingLine.from_curve(_curve, HALF_WIDTH)
	_centreline = RacingLine.from_curve(_curve, HALF_WIDTH, RacingLine.DEFAULT_SPACING_M, HALF_WIDTH)


func test_the_line_stays_inside_the_corridor() -> void:
	assert_almost_eq(_line.corridor_m, HALF_WIDTH - RacingLine.DEFAULT_EDGE_MARGIN_M, 0.001)
	var widest := 0.0
	for offset: float in _line.lateral_m:
		widest = maxf(widest, absf(offset))
	assert_lt(widest, _line.corridor_m + 0.001, "the line never leaves the road")
	assert_gt(widest, 1.0, "and it does use the road it is given")


func test_the_line_is_shorter_than_the_centreline() -> void:
	assert_lt(_line.length_m(), _centreline.length_m())
	assert_gt(_line.length_m(), _centreline.length_m() * 0.9, "but not by cutting the circuit")


func test_the_line_bends_less_than_the_centreline() -> void:
	assert_lt(_line.total_curvature(), _centreline.total_curvature() * 0.95)


func test_the_apex_sits_deeper_inside_than_the_entry_and_the_exit() -> void:
	var entry := _line.lateral_m[_line.index_for_offset(TURN_ONE_ENTRY_M)]
	var apex := _line.lateral_m[_line.index_for_offset(TURN_ONE_APEX_M)]
	var exit_line := _line.lateral_m[_line.index_for_offset(TURN_ONE_EXIT_M)]

	assert_gt(apex, entry, "turn one is a right hander, so the apex is to the right")
	assert_gt(apex, exit_line)
	assert_gt(apex, _line.corridor_m * 0.85, "the apex uses nearly the whole corridor")


func test_the_slowest_corner_is_far_below_the_top_speed() -> void:
	var slowest := RacingLine.DEFAULT_TOP_SPEED_KPH / 3.6
	var quickest := 0.0
	for speed: float in _line.speed_mps:
		slowest = minf(slowest, speed)
		quickest = maxf(quickest, speed)

	assert_lt(slowest * 3.6, 220.0, "the tight corners have to cost speed")
	assert_gt(slowest * 3.6, 60.0, "but the car is not crawling")
	assert_almost_eq(quickest * 3.6, RacingLine.DEFAULT_TOP_SPEED_KPH, 1.0)


func test_the_speed_profile_respects_the_braking_limit() -> void:
	var worst_g := 0.0
	for index: int in _line.points.size():
		var ahead := posmod(index + 1, _line.points.size())
		var step := _line.points[index].distance_to(_line.points[ahead])
		if step < 0.001:
			continue
		var here := _line.speed_mps[index]
		var next := _line.speed_mps[ahead]
		var demand := absf(here * here - next * next) / (2.0 * step * RacingLine.GRAVITY)
		worst_g = maxf(worst_g, demand)

	assert_lt(worst_g, RacingLine.DEFAULT_BRAKING_G * 1.05, "no step needs more than the tyres have")


func test_a_lap_at_this_pace_fits_the_race_length() -> void:
	var lap := _line.estimated_lap_seconds()
	assert_between(lap, 40.0, 120.0, "lap time in seconds")

	var race_minutes := lap * float(_track["race_laps"]) / 60.0
	assert_between(race_minutes, 5.0, 15.0, "PRD 43 target race length in minutes")


func test_lookups_agree_with_the_samples() -> void:
	var offset := 1234.0
	var index := _line.index_for_offset(offset)
	assert_eq(_line.point_for_offset(offset), _line.points[index])
	assert_almost_eq(_line.speed_for_offset(offset), _line.speed_mps[index], 0.0001)
	assert_eq(_line.index_for_offset(offset + _line.centreline_length_m), index, "offsets wrap")


func test_the_line_is_deterministic() -> void:
	var again := RacingLine.from_curve(_curve, HALF_WIDTH)
	assert_eq(again.points.size(), _line.points.size())

	var widest_difference := 0.0
	for index: int in again.lateral_m.size():
		widest_difference = maxf(widest_difference, absf(again.lateral_m[index] - _line.lateral_m[index]))
	assert_almost_eq(widest_difference, 0.0, 0.0001)


func test_a_curve_without_points_produces_an_empty_line() -> void:
	var empty := RacingLine.from_curve(Curve3D.new(), HALF_WIDTH)
	assert_eq(empty.points.size(), 0)
	assert_eq(empty.speed_for_offset(10.0), 0.0)
	assert_eq(empty.point_for_offset(10.0), Vector3.ZERO)


func test_a_straight_is_taken_at_top_speed() -> void:
	assert_eq(RacingLine.corner_speed(0.0, 2.2, 97.0), 97.0)


func test_a_tighter_corner_is_taken_slower() -> void:
	assert_lt(RacingLine.corner_speed(0.010, 2.2, 97.0), RacingLine.corner_speed(0.002, 2.2, 97.0))


func test_without_aero_the_solve_is_the_plain_grip_formula() -> void:
	var bend := 0.004
	var plain := sqrt(2.2 * RacingLine.GRAVITY / bend)
	assert_almost_eq(RacingLine.corner_speed(bend, 2.2, 500.0), plain, 0.0001)


func test_the_solve_never_exceeds_the_top_speed_it_was_given() -> void:
	for bend: float in [0.0, 0.0005, 0.002, 0.01, 0.05]:
		assert_lte(RacingLine.corner_speed(bend, 2.6, 80.0, 47.8, 0.0003, 0.85), 80.0,
			"curvature %.4f" % bend)


func test_grip_is_unchanged_at_the_speed_it_was_measured() -> void:
	assert_almost_eq(RacingLine.grip_at_speed(2.4, 47.8, 47.8, 0.0003, 0.85), 2.4, 0.0001)


func test_grip_falls_below_the_skidpad_figure_in_a_slow_corner() -> void:
	var slow := RacingLine.grip_at_speed(2.4, 47.8, 22.0, 0.0003, 0.85)
	assert_lt(slow, 2.4, "the downforce that made 2.4 g is not there at 79 km/h")


func test_grip_rises_above_the_skidpad_figure_in_a_fast_corner() -> void:
	assert_gt(RacingLine.grip_at_speed(2.4, 47.8, 80.0, 0.0003, 0.85), 2.4)


func test_a_car_without_downforce_keeps_one_grip_figure() -> void:
	assert_eq(RacingLine.grip_at_speed(1.7, 47.8, 20.0, 0.0, 0.85), 1.7)
	assert_eq(RacingLine.grip_at_speed(1.7, 47.8, 90.0, 0.0, 0.85), 1.7)


func test_a_winged_car_is_asked_to_go_slower_through_a_slow_corner() -> void:
	var tight := 0.020
	var flat := RacingLine.corner_speed(tight, 2.4, 200.0)
	var honest := RacingLine.corner_speed(tight, 2.4, 200.0, 47.8, 0.0003, 0.85)
	assert_lt(honest, flat, "a constant lateral g promises grip the slow corner does not have")


func test_a_winged_car_is_allowed_more_through_a_fast_corner() -> void:
	var open_bend := 0.0015
	var flat := RacingLine.corner_speed(open_bend, 2.4, 200.0)
	var honest := RacingLine.corner_speed(open_bend, 2.4, 200.0, 47.8, 0.0003, 0.85)
	assert_gt(honest, flat)


func test_the_corner_speed_solve_settles() -> void:
	var bend := 0.004
	var solved := RacingLine.corner_speed(bend, 2.4, 200.0, 47.8, 0.0003, 0.85)
	var available := RacingLine.grip_at_speed(2.4, 47.8, solved, 0.0003, 0.85)
	assert_almost_eq(solved * solved * bend, available * RacingLine.GRAVITY, 0.05,
		"the answer must be a speed the car can actually hold on that radius")


func test_the_default_speed_profile_is_unchanged_by_the_new_parameters() -> void:
	var line := RacingLine.from_curve(_curve, HALF_WIDTH)
	var defaults := line.speed_mps.duplicate()

	line.compute_speeds(
		RacingLine.DEFAULT_LATERAL_G,
		RacingLine.DEFAULT_BRAKING_G,
		RacingLine.DEFAULT_ACCELERATION_G,
		RacingLine.DEFAULT_TOP_SPEED_KPH
	)
	for index: int in defaults.size():
		assert_eq(line.speed_mps[index], defaults[index], "sample %d" % index)
