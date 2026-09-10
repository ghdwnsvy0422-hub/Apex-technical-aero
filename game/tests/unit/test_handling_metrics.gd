extends GutTest


func _ramp(steady: float, rise_samples: int, hold_samples: int) -> PackedFloat32Array:
	var series := PackedFloat32Array()
	for index: int in rise_samples:
		series.append(steady * float(index + 1) / float(rise_samples))
	for _index: int in hold_samples:
		series.append(steady)
	return series


func test_steady_value_averages_the_tail() -> void:
	var series := PackedFloat32Array([0.0, 0.0, 0.0, 2.0, 4.0])
	assert_almost_eq(HandlingMetrics.steady_value(series, 2), 3.0, 0.001)


func test_steady_value_clamps_window_to_series_length() -> void:
	var series := PackedFloat32Array([4.0])
	assert_almost_eq(HandlingMetrics.steady_value(series, 99), 4.0, 0.001)


func test_steady_value_of_empty_series_is_zero() -> void:
	assert_eq(HandlingMetrics.steady_value(PackedFloat32Array(), 4), 0.0)


func test_response_time_finds_the_ninety_percent_crossing() -> void:
	var series := _ramp(1.0, 100, 100)
	assert_almost_eq(
		HandlingMetrics.response_time(series, 0.9, 100, 100), 0.89, 0.011
	)


func test_a_faster_ramp_reports_a_shorter_response() -> void:
	var slow := HandlingMetrics.response_time(_ramp(1.0, 100, 100), 0.9, 100, 100)
	var fast := HandlingMetrics.response_time(_ramp(1.0, 20, 180), 0.9, 100, 100)
	assert_lt(fast, slow)


func test_response_time_of_a_flat_zero_series_is_zero() -> void:
	var series := PackedFloat32Array([0.0, 0.0, 0.0])
	assert_eq(HandlingMetrics.response_time(series, 0.9, 2, 120), 0.0)


func test_a_series_that_never_settles_reports_its_full_length() -> void:
	var series := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	assert_almost_eq(
		HandlingMetrics.response_time(series, 2.0, 2, 4), 1.0, 0.001
	)


func test_overshoot_of_a_settled_series_is_one() -> void:
	assert_almost_eq(HandlingMetrics.overshoot_ratio(_ramp(1.0, 10, 40), 20), 1.0, 0.001)


func test_overshoot_reports_the_peak_over_the_settled_value() -> void:
	var series := _ramp(1.0, 10, 40)
	series[12] = 1.5
	assert_almost_eq(HandlingMetrics.overshoot_ratio(series, 20), 1.5, 0.001)


func test_overshoot_of_an_empty_series_is_one() -> void:
	assert_eq(HandlingMetrics.overshoot_ratio(PackedFloat32Array(), 4), 1.0)


func test_balance_label_names_the_axle_that_slips_more() -> void:
	assert_eq(HandlingMetrics.balance_label(3.0), "understeer")
	assert_eq(HandlingMetrics.balance_label(-3.0), "oversteer")
	assert_eq(HandlingMetrics.balance_label(0.0), "neutral")


func test_balance_label_keeps_a_neutral_band() -> void:
	var edge := HandlingMetrics.NEUTRAL_BALANCE_BAND_DEG
	assert_eq(HandlingMetrics.balance_label(edge * 0.5), "neutral")
	assert_eq(HandlingMetrics.balance_label(-edge * 0.5), "neutral")
	assert_eq(HandlingMetrics.balance_label(edge * 2.0), "understeer")


func test_geometric_curvature_matches_the_bicycle_model() -> void:
	assert_almost_eq(
		HandlingMetrics.geometric_curvature(deg_to_rad(10.0), 3.6),
		tan(deg_to_rad(10.0)) / 3.6,
		0.00001
	)


func test_geometric_curvature_ignores_which_way_the_wheel_points() -> void:
	assert_almost_eq(
		HandlingMetrics.geometric_curvature(-0.2, 3.6),
		HandlingMetrics.geometric_curvature(0.2, 3.6),
		0.00001
	)


func test_geometric_curvature_of_a_zero_wheelbase_is_zero() -> void:
	assert_eq(HandlingMetrics.geometric_curvature(0.2, 0.0), 0.0)


func test_rotation_ratio_reads_one_when_the_car_follows_its_steering() -> void:
	assert_almost_eq(HandlingMetrics.rotation_ratio_of(0.02, 0.02), 1.0, 0.00001)


func test_rotation_ratio_is_below_one_when_the_car_runs_wide() -> void:
	assert_lt(HandlingMetrics.rotation_ratio_of(0.01, 0.02), 1.0)


func test_rotation_ratio_is_above_one_when_the_car_rotates_more() -> void:
	assert_gt(HandlingMetrics.rotation_ratio_of(0.04, 0.02), 1.0)


func test_rotation_ratio_of_a_straight_wheel_is_one() -> void:
	assert_eq(HandlingMetrics.rotation_ratio_of(0.02, 0.0), 1.0)


func test_body_slip_is_zero_when_the_car_points_where_it_travels() -> void:
	var car := CarBody.new()
	car.linear_velocity = Vector3.FORWARD * 40.0
	assert_almost_eq(HandlingMetrics.body_slip_deg(car), 0.0, 0.001)
	car.free()


func test_body_slip_measures_how_sideways_the_car_is() -> void:
	var car := CarBody.new()
	car.linear_velocity = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(30.0)) * 40.0
	assert_almost_eq(HandlingMetrics.body_slip_deg(car), 30.0, 0.01)
	car.free()


func test_body_slip_ignores_which_way_the_car_slides() -> void:
	var left := CarBody.new()
	left.linear_velocity = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-25.0)) * 40.0
	assert_almost_eq(HandlingMetrics.body_slip_deg(left), 25.0, 0.01)
	left.free()


func test_body_slip_ignores_vertical_motion() -> void:
	var car := CarBody.new()
	car.linear_velocity = Vector3.FORWARD * 40.0 + Vector3.UP * 12.0
	assert_almost_eq(HandlingMetrics.body_slip_deg(car), 0.0, 0.001)
	car.free()


func test_body_slip_of_a_stationary_car_is_zero() -> void:
	var car := CarBody.new()
	car.linear_velocity = Vector3.ZERO
	assert_eq(HandlingMetrics.body_slip_deg(car), 0.0)
	car.free()


func test_exit_blend_runs_from_corner_to_straight() -> void:
	assert_almost_eq(HandlingMetrics.exit_blend(0.0, 1.0), 0.0, 0.00001)
	assert_almost_eq(HandlingMetrics.exit_blend(0.5, 1.0), 0.5, 0.00001)
	assert_almost_eq(HandlingMetrics.exit_blend(1.0, 1.0), 1.0, 0.00001)


func test_exit_blend_holds_at_full_once_unwound() -> void:
	assert_almost_eq(HandlingMetrics.exit_blend(4.0, 1.0), 1.0, 0.00001)


func test_exit_blend_of_an_instant_unwind_is_immediate() -> void:
	assert_eq(HandlingMetrics.exit_blend(0.0, 0.0), 1.0)


func test_front_steer_angle_reports_the_applied_lock() -> void:
	var car := CarBody.new()
	var front := _wheel(true, 0.0)
	front.steer_angle = -0.25
	car.wheels = [front, _wheel(false, 0.0)]
	assert_almost_eq(HandlingMetrics.front_steer_angle(car), 0.25, 0.00001)
	car.free()


func test_axle_slip_balance_is_positive_when_the_front_slips_more() -> void:
	var car := CarBody.new()
	car.wheels = [
		_wheel(true, deg_to_rad(6.0)),
		_wheel(true, deg_to_rad(6.0)),
		_wheel(false, deg_to_rad(2.0)),
		_wheel(false, deg_to_rad(2.0)),
	]
	assert_almost_eq(HandlingMetrics.axle_slip_balance_deg(car), 4.0, 0.001)
	car.free()


func test_axle_slip_balance_ignores_the_sign_of_the_corner() -> void:
	var left := CarBody.new()
	left.wheels = [
		_wheel(true, deg_to_rad(-6.0)),
		_wheel(true, deg_to_rad(-6.0)),
		_wheel(false, deg_to_rad(-2.0)),
		_wheel(false, deg_to_rad(-2.0)),
	]
	assert_almost_eq(HandlingMetrics.axle_slip_balance_deg(left), 4.0, 0.001)
	left.free()


func test_axle_slip_balance_skips_airborne_wheels() -> void:
	var car := CarBody.new()
	var lifted := _wheel(true, deg_to_rad(40.0))
	lifted.grounded = false
	car.wheels = [
		_wheel(true, deg_to_rad(6.0)),
		lifted,
		_wheel(false, deg_to_rad(2.0)),
		_wheel(false, deg_to_rad(2.0)),
	]
	assert_almost_eq(HandlingMetrics.axle_slip_balance_deg(car), 4.0, 0.001)
	car.free()


func test_axle_slip_balance_is_zero_when_an_axle_is_off_the_ground() -> void:
	var car := CarBody.new()
	var front := _wheel(true, deg_to_rad(6.0))
	front.grounded = false
	car.wheels = [front, _wheel(false, deg_to_rad(2.0))]
	assert_eq(HandlingMetrics.axle_slip_balance_deg(car), 0.0)
	car.free()


func _wheel(is_front: bool, slip: float) -> Wheel:
	var wheel := Wheel.create(Vector3.ZERO, is_front, not is_front)
	wheel.grounded = true
	wheel.slip_angle = slip
	return wheel
