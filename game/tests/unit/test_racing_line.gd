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


func fading_acceleration() -> PackedVector2Array:
	return PackedVector2Array([Vector2(20.0, 1.0), Vector2(60.0, 0.6), Vector2(86.0, 0.0)])


func test_without_a_curve_the_single_acceleration_figure_is_used() -> void:
	assert_eq(RacingLine.acceleration_at(50.0, 0.55, PackedVector2Array()), 0.55)


func test_acceleration_is_read_off_the_curve_between_its_points() -> void:
	var curve := fading_acceleration()
	assert_almost_eq(RacingLine.acceleration_at(40.0, 0.55, curve), 0.8, 0.0001)
	assert_almost_eq(RacingLine.acceleration_at(73.0, 0.55, curve), 0.3, 0.0001)


func test_acceleration_holds_its_end_values_outside_the_curve() -> void:
	var curve := fading_acceleration()
	assert_eq(RacingLine.acceleration_at(5.0, 0.55, curve), 1.0)
	assert_eq(RacingLine.acceleration_at(120.0, 0.55, curve), 0.0)


func test_a_car_that_runs_out_of_breath_at_speed_is_given_a_slower_lap() -> void:
	var flat := RacingLine.from_curve(_curve, HALF_WIDTH)
	flat.compute_speeds(2.4, 2.1, 1.0, 310.0)

	var fading := RacingLine.from_curve(_curve, HALF_WIDTH)
	fading.compute_speeds(2.4, 2.1, 1.0, 310.0, fading_acceleration())

	assert_gt(fading.estimated_lap_seconds(), flat.estimated_lap_seconds())
	assert_lt(fading.speed_for_offset(700.0), flat.speed_for_offset(700.0),
		"the end of the main straight is where fading acceleration costs most")


func test_a_tyre_that_is_not_cornering_has_all_its_grip_left() -> void:
	assert_eq(RacingLine.grip_left(80.0, 0.0, 23.5), 1.0)


func test_a_tyre_at_the_cornering_limit_has_no_grip_left() -> void:
	var limit := 23.5
	var bend := 1.0 / 90.0
	var limit_speed := sqrt(limit / bend)
	assert_almost_eq(RacingLine.grip_left(limit_speed, bend, limit), 0.0, 0.001)
	assert_eq(RacingLine.grip_left(limit_speed * 1.2, bend, limit), 0.0, "never negative")
	assert_between(RacingLine.grip_left(limit_speed * 0.8, bend, limit), 0.5, 0.99)


func test_the_profile_never_accelerates_harder_than_the_cornering_tyres_allow() -> void:
	var lateral_limit := RacingLine.DEFAULT_LATERAL_G * RacingLine.GRAVITY
	var count := _line.points.size()
	var worst_excess := 0.0
	for index: int in count:
		var ahead := posmod(index + 1, count)
		var step := _line.points[index].distance_to(_line.points[ahead])
		var here := _line.speed_mps[index]
		var next := _line.speed_mps[ahead]
		if step < 0.001 or next <= here:
			continue
		var asked_g := (next * next - here * here) / (2.0 * step * RacingLine.GRAVITY)
		var tyre_g := RacingLine.DEFAULT_LATERAL_G * RacingLine.grip_left(
			here, _line.curvature[index], lateral_limit
		)
		worst_excess = maxf(worst_excess, asked_g - tyre_g)
	assert_lt(worst_excess, 0.01, "acceleration and cornering share one tyre")


func test_the_drive_share_is_whole_on_the_straight_and_reduced_at_the_apex() -> void:
	assert_eq(_line.drive_share.size(), _line.points.size())
	assert_eq(_line.drive_share_for_offset(300.0), 1.0, "nothing to share on the main straight")
	assert_lt(_line.drive_share_for_offset(TURN_ONE_APEX_M), 0.5,
		"at the apex the tyres are busy turning the car")
	for share: float in _line.drive_share:
		assert_between(share, 0.0, 1.0)


func test_a_line_without_speeds_shares_nothing_out() -> void:
	assert_eq(RacingLine.new().drive_share_for_offset(100.0), 1.0)
