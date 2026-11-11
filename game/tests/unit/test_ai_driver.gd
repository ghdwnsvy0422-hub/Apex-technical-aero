extends GutTest

const Registry := preload("res://core/data_registry.gd")

const SHIPPED_TRACK := "res://data/tracks/aurora_speedway.json"
const HALF_WIDTH: float = 7.5

var _curve: Curve3D
var _line: RacingLine
var _driver: AiDriver


func before_all() -> void:
	var track := Registry.read_json(SHIPPED_TRACK) as Dictionary
	_curve = TrackCompiler.curve_from(track)
	_line = RacingLine.from_curve(_curve, HALF_WIDTH)
	_driver = AiDriver.create(_line, _curve)


func facing_forward() -> Transform3D:
	return Transform3D.IDENTITY


func test_a_target_to_the_right_steers_right() -> void:
	var steer := AiDriver.steer_towards_point(facing_forward(), Vector3(10.0, 0.0, -20.0))
	assert_gt(steer, 0.0, "Godot forward is -Z, so +X is the car's right")


func test_a_target_to_the_left_steers_left() -> void:
	var steer := AiDriver.steer_towards_point(facing_forward(), Vector3(-10.0, 0.0, -20.0))
	assert_lt(steer, 0.0)


func test_a_target_straight_ahead_holds_the_wheel() -> void:
	var steer := AiDriver.steer_towards_point(facing_forward(), Vector3(0.0, 0.0, -40.0))
	assert_almost_eq(steer, 0.0, 0.001)


func test_steering_is_clamped_to_full_lock() -> void:
	var hard := AiDriver.steer_towards_point(facing_forward(), Vector3(60.0, 0.0, -1.0))
	assert_almost_eq(hard, 1.0, 0.0001)


func test_a_target_underfoot_is_ignored() -> void:
	assert_eq(AiDriver.steer_towards_point(facing_forward(), Vector3(0.2, 0.0, 0.2)), 0.0)


func test_height_does_not_leak_into_steering() -> void:
	var flat := AiDriver.steer_towards_point(facing_forward(), Vector3(10.0, 0.0, -20.0))
	var uphill := AiDriver.steer_towards_point(facing_forward(), Vector3(10.0, 25.0, -20.0))
	assert_almost_eq(uphill, flat, 0.0001, "elevation must not change the steering angle")


func test_the_car_accelerates_when_it_is_below_the_target_speed() -> void:
	assert_gt(AiDriver.throttle_for(40.0, 70.0), 0.0)
	assert_eq(AiDriver.brake_for(40.0, 70.0), 0.0)


func test_the_car_brakes_when_it_is_above_the_target_speed() -> void:
	assert_gt(AiDriver.brake_for(80.0, 40.0), 0.0)
	assert_eq(AiDriver.throttle_for(80.0, 40.0), 0.0)


func test_throttle_and_brake_are_never_asked_for_together() -> void:
	for speed: float in [0.0, 5.0, 30.0, 60.0, 90.0]:
		for target: float in [0.0, 20.0, 55.0, 97.0]:
			var both := AiDriver.throttle_for(speed, target) * AiDriver.brake_for(speed, target)
			assert_eq(both, 0.0, "at %.0f m/s aiming for %.0f m/s" % [speed, target])


func test_the_deadband_leaves_a_car_at_its_target_speed_alone() -> void:
	assert_eq(AiDriver.throttle_for(50.0, 50.0), 0.0)
	assert_eq(AiDriver.brake_for(50.0, 50.0), 0.0)


func test_traction_limits_the_throttle_from_a_standstill() -> void:
	var launch := AiDriver.throttle_for(0.0, 90.0)
	assert_lt(launch, 0.5, "a 1000 hp car pinned from rest only spins its wheels")
	assert_gt(launch, 0.0, "but it still has to pull away")
	assert_almost_eq(AiDriver.throttle_for(40.0, 90.0), 1.0, 0.0001, "the limit lifts with speed")


func test_lookahead_grows_with_speed_but_stays_bounded() -> void:
	assert_eq(AiDriver.new().lookahead_for(0.0), AiDriver.MIN_LOOKAHEAD_M)
	assert_eq(AiDriver.new().lookahead_for(500.0), AiDriver.MAX_LOOKAHEAD_M)
	var cruising := AiDriver.new().lookahead_for(60.0)
	assert_between(cruising, AiDriver.MIN_LOOKAHEAD_M, AiDriver.MAX_LOOKAHEAD_M)


func test_a_driver_without_a_line_sits_still() -> void:
	var blind := AiDriver.create(RacingLine.new(), null)
	assert_false(blind.is_ready())
	var input := blind.input_for(Transform3D.IDENTITY, Vector3.ZERO)
	assert_eq(input.throttle, 0.0)
	assert_eq(input.brake, 0.0)
	assert_eq(input.steer, 0.0)


func test_the_driver_aims_at_the_racing_line_rather_than_the_centreline() -> void:
	var offset := 944.0
	var apex := _line.point_for_offset(offset)
	var centre := _curve.sample_baked(offset)
	assert_gt(apex.distance_to(centre), 1.0, "turn one apex is off the centreline")

	var here := _driver.centreline_offset(apex)
	assert_almost_eq(here, offset, 12.0, "the apex maps back to the offset it came from")


func test_the_driver_asks_for_a_sane_input_everywhere_on_the_lap() -> void:
	var offset := 0.0
	while offset < _line.centreline_length_m:
		var frame := TrackGeometry.frame_at(_curve, offset, _line.centreline_length_m)
		var speed := _line.speed_for_offset(offset)
		var input := _driver.input_for(frame, frame.basis * Vector3.FORWARD * speed)

		assert_between(input.steer, -1.0, 1.0, "steer at %.0f m" % offset)
		assert_between(input.throttle, 0.0, 1.0, "throttle at %.0f m" % offset)
		assert_between(input.brake, 0.0, 1.0, "brake at %.0f m" % offset)
		assert_eq(input.throttle * input.brake, 0.0, "no braking on the throttle at %.0f m" % offset)
		offset += 50.0


func travelling(heading_offset_rad: float, speed: float) -> Vector3:
	return (Vector3.FORWARD * speed).rotated(Vector3.UP, heading_offset_rad)


func test_a_car_travelling_where_it_points_has_no_sideslip() -> void:
	assert_almost_eq(AiDriver.sideslip(facing_forward(), travelling(0.0, 50.0)), 0.0, 0.0001)


func test_sideslip_is_the_angle_between_the_nose_and_the_direction_of_travel() -> void:
	var one_way := AiDriver.sideslip(facing_forward(), travelling(0.1, 50.0))
	var other_way := AiDriver.sideslip(facing_forward(), travelling(-0.1, 50.0))
	assert_almost_eq(absf(one_way), 0.1, 0.0001)
	assert_almost_eq(one_way, -other_way, 0.0001, "sliding left and right mirror each other")


func test_sideslip_follows_the_car_rather_than_the_world() -> void:
	var turned := Transform3D(Basis(Vector3.UP, 0.7), Vector3.ZERO)
	assert_almost_eq(AiDriver.sideslip(turned, travelling(0.7, 50.0)), 0.0, 0.0001)


func test_sideslip_is_ignored_at_a_crawl() -> void:
	var crawl := AiDriver.SIDESLIP_MIN_SPEED_MPS * 0.5
	assert_eq(AiDriver.sideslip(facing_forward(), travelling(1.2, crawl)), 0.0)


func test_vertical_speed_does_not_leak_into_sideslip() -> void:
	var bouncing := travelling(0.0, 50.0) + Vector3.UP * 20.0
	assert_almost_eq(AiDriver.sideslip(facing_forward(), bouncing), 0.0, 0.0001)


func test_a_car_that_is_not_sliding_keeps_its_full_throttle() -> void:
	assert_eq(AiDriver.slide_throttle_limit(0.0), 1.0)
	assert_eq(AiDriver.slide_throttle_limit(AiDriver.SLIDE_ONSET_RAD), 1.0)
	assert_eq(AiDriver.slide_throttle_limit(-AiDriver.SLIDE_ONSET_RAD), 1.0)


func test_a_slide_takes_the_throttle_away_progressively() -> void:
	var midway := (AiDriver.SLIDE_ONSET_RAD + AiDriver.SLIDE_LIMIT_RAD) * 0.5
	var early := AiDriver.slide_throttle_limit(lerpf(AiDriver.SLIDE_ONSET_RAD, midway, 0.5))
	var late := AiDriver.slide_throttle_limit(lerpf(midway, AiDriver.SLIDE_LIMIT_RAD, 0.5))
	assert_between(early, 0.0, 1.0)
	assert_lt(late, early, "the further the tail is out, the less throttle is left")
	assert_eq(AiDriver.slide_throttle_limit(AiDriver.SLIDE_LIMIT_RAD), 0.0)
	assert_eq(AiDriver.slide_throttle_limit(1.5), 0.0, "a spin gets no throttle at all")


func test_the_slide_limit_treats_both_directions_alike() -> void:
	var midway := (AiDriver.SLIDE_ONSET_RAD + AiDriver.SLIDE_LIMIT_RAD) * 0.5
	assert_eq(AiDriver.slide_throttle_limit(midway), AiDriver.slide_throttle_limit(-midway))


func test_the_grip_the_healthy_setups_corner_at_is_below_the_slide_onset() -> void:
	assert_gt(AiDriver.SLIDE_ONSET_RAD, deg_to_rad(2.5), "they peak near 2.3 degrees of sideslip")


func test_the_driver_lifts_when_the_tail_steps_out_below_the_target_speed() -> void:
	var offset := 300.0
	var frame := TrackGeometry.frame_at(_curve, offset, _line.centreline_length_m)
	var slow := _line.speed_for_offset(offset) * 0.5
	var nose := frame.basis * Vector3.FORWARD

	var planted := _driver.input_for(frame, nose * slow)
	var sliding := _driver.input_for(frame, nose.rotated(Vector3.UP, 0.2) * slow)

	assert_gt(planted.throttle, 0.0, "below the target speed it wants to accelerate")
	assert_eq(sliding.throttle, 0.0, "but not while the car is sideways")


func test_a_slide_does_not_stop_the_driver_braking() -> void:
	var offset := 300.0
	var frame := TrackGeometry.frame_at(_curve, offset, _line.centreline_length_m)
	var fast := _line.speed_for_offset(offset) * 1.5
	var nose := frame.basis * Vector3.FORWARD

	var sliding := _driver.input_for(frame, nose.rotated(Vector3.UP, 0.2) * fast)

	assert_gt(sliding.brake, 0.0)
	assert_eq(sliding.throttle, 0.0)


func test_a_plan_that_is_gaining_speed_gets_more_throttle() -> void:
	var holding := AiDriver.throttle_for(60.0, 61.0)
	var gaining := AiDriver.throttle_for(60.0, 61.0, 0.5)
	assert_lt(holding, 0.5, "one metre per second short is only a nudge")
	assert_eq(gaining, 1.0, "but a plan that is accelerating wants the car flat out")


func test_a_plan_that_is_slowing_does_not_take_throttle_away() -> void:
	assert_eq(AiDriver.throttle_for(60.0, 62.0, -4.0), AiDriver.throttle_for(60.0, 62.0))


func test_a_gaining_plan_does_not_push_a_car_past_its_target() -> void:
	assert_eq(AiDriver.throttle_for(60.0, 60.0, 3.0), 0.0)


func test_the_launch_limit_still_holds_when_the_plan_is_gaining() -> void:
	assert_lt(AiDriver.throttle_for(0.0, 90.0, 5.0), 0.5)


func test_cornering_tyres_cap_the_throttle() -> void:
	assert_eq(AiDriver.cornering_throttle_limit(1.0), 1.0)
	assert_eq(AiDriver.cornering_throttle_limit(0.0), AiDriver.CORNERING_THROTTLE)
	assert_between(AiDriver.cornering_throttle_limit(0.5), AiDriver.CORNERING_THROTTLE, 1.0)
	assert_eq(AiDriver.cornering_throttle_limit(-2.0), AiDriver.CORNERING_THROTTLE)
	assert_eq(AiDriver.cornering_throttle_limit(3.0), 1.0)


func test_the_driver_holds_back_at_the_apex_but_not_on_the_straight() -> void:
	var apex_frame := TrackGeometry.frame_at(_curve, 944.0, _line.centreline_length_m)
	var apex_speed := _line.speed_for_offset(944.0) * 0.6
	var at_apex := _driver.input_for(apex_frame, apex_frame.basis * Vector3.FORWARD * apex_speed)

	var straight_frame := TrackGeometry.frame_at(_curve, 300.0, _line.centreline_length_m)
	var straight_speed := _line.speed_for_offset(300.0) * 0.6
	var on_straight := _driver.input_for(
		straight_frame, straight_frame.basis * Vector3.FORWARD * straight_speed
	)

	assert_eq(on_straight.throttle, 1.0)
	assert_gt(at_apex.throttle, 0.0)
	assert_lt(at_apex.throttle, 1.0, "the tyres are still turning the car")


func test_the_driver_looks_less_far_ahead_to_brake_than_to_accelerate() -> void:
	assert_lt(AiDriver.BRAKE_PREVIEW_SECONDS, AiDriver.SPEED_PREVIEW_SECONDS)


func test_braking_always_wins_over_the_throttle() -> void:
	var offset := 0.0
	while offset < _line.centreline_length_m:
		var frame := TrackGeometry.frame_at(_curve, offset, _line.centreline_length_m)
		for scale: float in [0.7, 1.0, 1.15]:
			var speed := _line.speed_for_offset(offset) * scale
			var input := _driver.input_for(frame, frame.basis * Vector3.FORWARD * speed)
			assert_eq(input.throttle * input.brake, 0.0, "at %.0f m, %.0f%% pace" % [offset, scale * 100.0])
		offset += 40.0
