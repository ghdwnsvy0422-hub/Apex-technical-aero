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


func travelling(heading_deg: float, speed: float) -> Vector3:
	return Vector3(0.0, 0.0, -speed).rotated(Vector3.UP, -deg_to_rad(heading_deg))


func test_a_car_going_where_it_points_has_no_slip() -> void:
	var slip := AiDriver.body_slip_angle(facing_forward(), Vector3(0.0, 0.0, -80.0))
	assert_almost_eq(slip, 0.0, 0.0001)


func test_travelling_right_of_the_nose_reads_as_positive_slip() -> void:
	var slip := AiDriver.body_slip_angle(facing_forward(), travelling(30.0, 60.0))
	assert_almost_eq(rad_to_deg(slip), 30.0, 0.01)


func test_travelling_left_of_the_nose_reads_as_negative_slip() -> void:
	var slip := AiDriver.body_slip_angle(facing_forward(), travelling(-30.0, 60.0))
	assert_almost_eq(rad_to_deg(slip), -30.0, 0.01)


func test_vertical_motion_does_not_read_as_slip() -> void:
	var dropping := Vector3(0.0, -9.0, -80.0)
	assert_almost_eq(AiDriver.body_slip_angle(facing_forward(), dropping), 0.0, 0.0001)


func test_a_nearly_stationary_car_reports_no_slip() -> void:
	var crawling := travelling(45.0, AiDriver.SLIP_MEASURABLE_MPS - 0.5)
	assert_eq(AiDriver.body_slip_angle(facing_forward(), crawling), 0.0)


func test_the_driver_steers_into_the_slide() -> void:
	assert_gt(AiDriver.countersteer_for(deg_to_rad(25.0)), 0.0)
	assert_lt(AiDriver.countersteer_for(deg_to_rad(-25.0)), 0.0)


func test_countersteer_reaches_full_lock_in_a_big_slide() -> void:
	assert_almost_eq(AiDriver.countersteer_for(deg_to_rad(90.0)), 1.0, 0.0001)
	assert_almost_eq(AiDriver.countersteer_for(deg_to_rad(-90.0)), -1.0, 0.0001)


func test_cornering_slip_is_left_alone() -> void:
	for slip_deg: float in [-2.5, -1.7, 0.0, 1.7, 2.5]:
		var slip := deg_to_rad(slip_deg)
		assert_eq(AiDriver.countersteer_for(slip), 0.0, "%.1f deg is ordinary cornering" % slip_deg)
		assert_eq(AiDriver.slide_throttle_ceiling(slip), 1.0)
		assert_eq(AiDriver.slide_brake_ceiling(slip), 1.0)


func test_a_slide_takes_the_throttle_away() -> void:
	var sliding := AiDriver.slide_throttle_ceiling(deg_to_rad(20.0))
	assert_almost_eq(sliding, AiDriver.SLIDE_THROTTLE_FLOOR, 0.0001)
	assert_lt(AiDriver.slide_throttle_ceiling(deg_to_rad(8.0)), 1.0)


func test_a_slide_eases_off_the_brake() -> void:
	var sliding := AiDriver.slide_brake_ceiling(deg_to_rad(20.0))
	assert_almost_eq(sliding, AiDriver.SLIDE_BRAKE_FLOOR, 0.0001)


func test_the_slide_response_grows_with_the_slide() -> void:
	var mild := AiDriver.slide_throttle_ceiling(deg_to_rad(7.0))
	var worse := AiDriver.slide_throttle_ceiling(deg_to_rad(11.0))
	assert_lt(worse, mild)
	assert_gt(AiDriver.countersteer_for(deg_to_rad(11.0)), AiDriver.countersteer_for(deg_to_rad(7.0)))


func test_a_spinning_car_gets_countersteer_and_no_throttle() -> void:
	var spun := travelling(45.0, 40.0)
	var input := _driver.input_for(facing_forward(), spun)
	assert_gt(input.steer, 0.5, "the wheel goes into the slide")
	assert_lt(input.throttle, 0.2, "and the power comes off")
