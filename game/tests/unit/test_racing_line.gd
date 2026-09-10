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


func test_acceleration_is_unchanged_at_the_speed_it_was_measured() -> void:
	assert_almost_eq(RacingLine.acceleration_at_speed(0.93, 41.7, 41.7, 86.0), 0.93, 0.0001)


func test_acceleration_falls_away_towards_top_speed() -> void:
	var mid := RacingLine.acceleration_at_speed(0.93, 41.7, 60.0, 86.0)
	var late := RacingLine.acceleration_at_speed(0.93, 41.7, 80.0, 86.0)
	assert_lt(late, mid)
	assert_lt(mid, 0.93, "a car pulls less at 216 km/h than at 150 km/h")


func test_a_car_at_its_top_speed_cannot_accelerate() -> void:
	assert_almost_eq(RacingLine.acceleration_at_speed(0.93, 41.7, 86.0, 86.0), 0.0, 0.0001)


func test_acceleration_never_goes_negative_past_top_speed() -> void:
	assert_eq(RacingLine.acceleration_at_speed(0.93, 41.7, 200.0, 86.0), 0.0)


func test_without_a_reference_speed_acceleration_stays_constant() -> void:
	assert_eq(RacingLine.acceleration_at_speed(0.55, 0.0, 20.0, 86.0), 0.55)
	assert_eq(RacingLine.acceleration_at_speed(0.55, 0.0, 80.0, 86.0), 0.55)


func test_the_speed_profile_stops_promising_a_speed_the_car_cannot_reach() -> void:
	var optimistic := RacingLine.from_curve(_curve, HALF_WIDTH)
	optimistic.compute_speeds(2.4, 2.0, 0.93, 310.0)

	var honest := RacingLine.from_curve(_curve, HALF_WIDTH)
	honest.compute_speeds(2.4, 2.0, 0.93, 310.0, 0.0, 0.0, 1.0, 41.7)

	assert_gt(honest.estimated_lap_seconds(), optimistic.estimated_lap_seconds(),
		"an ideal lap that assumes constant acceleration to top speed is not achievable")


func test_the_default_speed_profile_survives_the_acceleration_model() -> void:
	var line := RacingLine.from_curve(_curve, HALF_WIDTH)
	var defaults := line.speed_mps.duplicate()
	line.compute_speeds()
	for index: int in defaults.size():
		assert_eq(line.speed_mps[index], defaults[index], "sample %d" % index)


func test_acceleration_below_the_measured_speed_is_capped_at_what_was_measured() -> void:
	for slow: float in [5.0, 10.0, 20.0, 30.0, 41.7]:
		assert_lte(RacingLine.acceleration_at_speed(0.93, 41.7, slow, 86.0), 0.93,
			"a car out of a slow corner is traction limited, not power limited (%.0f m/s)" % slow)


func test_the_power_model_would_otherwise_demand_impossible_acceleration() -> void:
	var raw := 0.93 * RacingLine.drive_shape(10.0, 86.0) / RacingLine.drive_shape(41.7, 86.0)
	assert_gt(raw, 2.0, "the unclamped shape diverges as speed falls")
	assert_lte(RacingLine.acceleration_at_speed(0.93, 41.7, 10.0, 86.0), 0.93)


func test_a_car_going_straight_has_its_whole_grip_for_the_throttle() -> void:
	var usage := RacingLine.lateral_usage(0.0, 60.0, 2.4, 47.8, 0.0003, 0.85)
	assert_eq(usage, 0.0)
	assert_eq(RacingLine.longitudinal_share(usage), 1.0)


func test_a_car_at_its_cornering_limit_has_nothing_left_for_the_throttle() -> void:
	var bend := 0.004
	var speed := RacingLine.corner_speed(bend, 2.4, 200.0, 47.8, 0.0003, 0.85)
	var usage := RacingLine.lateral_usage(bend, speed, 2.4, 47.8, 0.0003, 0.85)
	assert_almost_eq(usage, 1.0, 0.01, "corner speed is by definition the lateral limit")
	assert_almost_eq(RacingLine.longitudinal_share(usage), 0.0, 0.1)


func test_a_car_well_below_the_corner_speed_keeps_headroom_for_the_throttle() -> void:
	var bend := 0.004
	var limit := RacingLine.corner_speed(bend, 2.4, 200.0, 47.8, 0.0003, 0.85)
	var slow := RacingLine.longitudinal_share(
		RacingLine.lateral_usage(bend, limit * 0.5, 2.4, 47.8, 0.0003, 0.85)
	)
	var at_limit := RacingLine.longitudinal_share(
		RacingLine.lateral_usage(bend, limit, 2.4, 47.8, 0.0003, 0.85)
	)
	assert_gt(slow, 0.5, "well inside the corner there is grip to spare")
	assert_gt(slow, at_limit)


func test_slowing_down_frees_less_grip_than_it_would_without_downforce() -> void:
	var bend := 0.004
	var winged := RacingLine.lateral_usage(bend, 40.0, 2.4, 47.8, 0.0003, 0.85)
	var wingless := RacingLine.lateral_usage(bend, 40.0, 2.4, 47.8, 0.0, 0.85)
	assert_gt(winged, wingless,
		"a winged car loses grip as it slows, so backing off frees less than the speed suggests")


func test_usage_grows_as_the_car_approaches_the_limit() -> void:
	var bend := 0.004
	var slow := RacingLine.lateral_usage(bend, 40.0, 2.4, 47.8, 0.0003, 0.85)
	var quick := RacingLine.lateral_usage(bend, 60.0, 2.4, 47.8, 0.0003, 0.85)
	assert_lt(slow, quick)


func test_the_circle_is_off_without_a_measured_grip_model() -> void:
	assert_eq(RacingLine.lateral_usage(0.02, 60.0, 2.4, 0.0, 0.0, 1.0), 0.0,
		"a line built from defaults keeps the old independent limits")


func test_the_circle_makes_the_ideal_lap_honest_rather_than_faster() -> void:
	var independent := RacingLine.from_curve(_curve, HALF_WIDTH)
	independent.compute_speeds(2.4, 2.1, 0.93, 310.0, 0.0, 0.0, 1.0, 41.7)

	var circled := RacingLine.from_curve(_curve, HALF_WIDTH)
	circled.compute_speeds(2.4, 2.1, 0.93, 310.0, 47.8, 0.00031, 0.85, 41.7, 47.2)

	assert_gt(circled.estimated_lap_seconds(), 0.0)
	assert_lt(
		RacingLine.longitudinal_share(
			RacingLine.lateral_usage(0.006, 45.0, 2.4, 47.8, 0.00031, 0.85)
		),
		1.0,
		"braking and throttle must give way to cornering where the line bends"
	)


func test_the_default_profile_survives_the_friction_circle() -> void:
	var line := RacingLine.from_curve(_curve, HALF_WIDTH)
	var defaults := line.speed_mps.duplicate()
	line.compute_speeds()
	for index: int in defaults.size():
		assert_eq(line.speed_mps[index], defaults[index], "sample %d" % index)
