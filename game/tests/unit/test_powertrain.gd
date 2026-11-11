extends GutTest
## Gearing and the torque curve. Gear selection in particular has already
## produced two distinct failures - short-shifting to top gear during
## wheelspin, and oscillating between two gears - so its rules are pinned.

var _setup: CarSetup


func before_each() -> void:
	_setup = CarSetup.new()


func test_torque_peaks_at_the_peak_rpm() -> void:
	assert_almost_eq(
		Powertrain.torque_fraction(_setup.engine_peak_torque_rpm, _setup), 1.0, 0.001
	)


func test_limiter_cuts_torque_completely() -> void:
	# What stops a spinning wheel from accelerating without bound.
	assert_eq(Powertrain.torque_fraction(_setup.engine_max_rpm + 1.0, _setup), 0.0)


func test_torque_falls_away_either_side_of_the_peak() -> void:
	var peak: float = Powertrain.torque_fraction(_setup.engine_peak_torque_rpm, _setup)
	assert_lt(Powertrain.torque_fraction(_setup.engine_idle_rpm, _setup), peak)
	assert_lt(Powertrain.torque_fraction(_setup.engine_max_rpm, _setup), peak)


func test_closed_throttle_makes_no_torque() -> void:
	assert_eq(Powertrain.engine_torque(10000.0, 0.0, _setup), 0.0)


func test_engine_speed_never_falls_below_idle() -> void:
	assert_eq(Powertrain.engine_rpm(0.0, 10.0, _setup.engine_idle_rpm), _setup.engine_idle_rpm)


func test_engine_speed_rises_with_wheel_speed() -> void:
	assert_gt(
		Powertrain.engine_rpm(200.0, 10.0, _setup.engine_idle_rpm),
		Powertrain.engine_rpm(100.0, 10.0, _setup.engine_idle_rpm)
	)


func test_ratios_shorten_as_the_box_goes_up() -> void:
	for gear: int in _setup.gear_ratios.size() - 1:
		assert_gt(
			Powertrain.total_ratio(gear, _setup),
			Powertrain.total_ratio(gear + 1, _setup)
		)


func test_invalid_gear_has_no_ratio() -> void:
	assert_eq(Powertrain.total_ratio(-1, _setup), 0.0)
	assert_eq(Powertrain.total_ratio(_setup.gear_ratios.size(), _setup), 0.0)


func test_shifts_up_at_the_threshold() -> void:
	assert_eq(Powertrain.select_gear(2, _setup.shift_up_rpm, _setup), 3)


func test_shifts_down_at_the_threshold() -> void:
	assert_eq(Powertrain.select_gear(2, _setup.shift_down_rpm, _setup), 1)


func test_holds_gear_between_thresholds() -> void:
	var midpoint := (_setup.shift_up_rpm + _setup.shift_down_rpm) * 0.5
	assert_eq(Powertrain.select_gear(2, midpoint, _setup), 2)


func test_thresholds_do_not_overlap() -> void:
	# Overlapping thresholds would let a gear shift up and immediately qualify
	# to shift back down, oscillating every tick.
	assert_lt(_setup.shift_down_rpm, _setup.shift_up_rpm)


func test_gear_selection_clamps_at_both_ends() -> void:
	var top := _setup.gear_ratios.size() - 1
	assert_eq(Powertrain.select_gear(top, _setup.shift_up_rpm, _setup), top)
	assert_eq(Powertrain.select_gear(0, _setup.shift_down_rpm, _setup), 0)


func test_brake_torque_splits_by_balance_across_four_wheels() -> void:
	var front: float = Powertrain.brake_torque(1.0, true, _setup)
	var rear: float = Powertrain.brake_torque(1.0, false, _setup)
	assert_almost_eq(2.0 * front + 2.0 * rear, _setup.max_brake_torque, 0.01)
	assert_gt(front, rear, "default balance is front biased")


func test_no_brake_input_makes_no_brake_torque() -> void:
	assert_eq(Powertrain.brake_torque(0.0, true, _setup), 0.0)
