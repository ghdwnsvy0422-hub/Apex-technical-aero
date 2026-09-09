extends GutTest

const Registry := preload("res://core/data_registry.gd")

const SHIPPED_TRACK := "res://data/tracks/aurora_speedway.json"
const HALF_WIDTH: float = 7.5

var _curve: Curve3D


func before_all() -> void:
	var track := Registry.read_json(SHIPPED_TRACK) as Dictionary
	_curve = TrackCompiler.curve_from(track)


func fresh_line() -> RacingLine:
	return RacingLine.from_curve(_curve, HALF_WIDTH)


func envelope(top_kph: float, lateral: float, braking: float, acceleration: float) -> PerformanceEnvelope:
	var measured := PerformanceEnvelope.new()
	measured.top_speed_kph = top_kph
	measured.lateral_g = lateral
	measured.braking_g = braking
	measured.acceleration_g = acceleration
	return measured


func slowest_corner_kph(line: RacingLine) -> float:
	var slowest := INF
	for speed: float in line.speed_mps:
		slowest = minf(slowest, speed)
	return slowest * 3.6


func test_the_launch_ramp_starts_part_throttle_and_reaches_full() -> void:
	assert_between(PerformanceEnvelope.launch_throttle(0.0), 0.0, 0.5,
		"pinning 1000 hp from rest only spins the tyres")
	assert_eq(PerformanceEnvelope.launch_throttle(10.0), 1.0)
	assert_gt(PerformanceEnvelope.launch_throttle(1.0), PerformanceEnvelope.launch_throttle(0.0))


func test_more_grip_raises_the_corner_speeds() -> void:
	var slow := fresh_line()
	envelope(300.0, 1.8, 2.0, 0.9).apply_to(slow)

	var quick := fresh_line()
	envelope(300.0, 2.6, 2.0, 0.9).apply_to(quick)

	assert_gt(slowest_corner_kph(quick), slowest_corner_kph(slow),
		"a grippier car must be asked to carry more speed through the corners")
	assert_lt(quick.estimated_lap_seconds(), slow.estimated_lap_seconds())


func test_a_lower_top_speed_costs_lap_time() -> void:
	var fast := fresh_line()
	envelope(340.0, 2.2, 2.0, 0.9).apply_to(fast)

	var slow := fresh_line()
	envelope(280.0, 2.2, 2.0, 0.9).apply_to(slow)

	assert_gt(slow.estimated_lap_seconds(), fast.estimated_lap_seconds())


func test_the_profile_still_respects_the_braking_limit_it_was_given() -> void:
	var line := fresh_line()
	var braking_g := 2.4
	envelope(320.0, 2.6, braking_g, 0.9).apply_to(line)

	var worst := 0.0
	for index: int in line.points.size():
		var ahead := posmod(index + 1, line.points.size())
		var step := line.points[index].distance_to(line.points[ahead])
		if step < 0.001:
			continue
		var here := line.speed_mps[index]
		var next := line.speed_mps[ahead]
		worst = maxf(worst, absf(here * here - next * next) / (2.0 * step * RacingLine.GRAVITY))

	assert_lt(worst, braking_g * 1.05, "no step may demand more braking than was measured")


func test_the_description_reports_every_measured_axis() -> void:
	var text := envelope(311.0, 2.41, 2.11, 0.93).describe()
	assert_string_contains(text, "311")
	assert_string_contains(text, "2.41")
	assert_string_contains(text, "2.11")
	assert_string_contains(text, "0.93")
