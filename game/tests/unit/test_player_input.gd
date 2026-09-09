extends GutTest
## Input smoothing. Keys are binary, so without ramping the car gets full lock
## in a single tick and cannot be placed on the road at all.

const Controls := preload("res://client/player_input.gd")

var _controls: PlayerInput


func before_each() -> void:
	_controls = Controls.new()


func after_each() -> void:
	_controls.free()


func _hold(steer: float, ticks: int, delta: float = 1.0 / 120.0) -> DriverInput:
	var result: DriverInput = null
	for _tick: int in ticks:
		result = _controls._advance(steer, 0.0, 0.0, false, delta)
	return result


func test_steering_does_not_snap_to_full_lock() -> void:
	var first: DriverInput = _controls._advance(1.0, 0.0, 0.0, false, 1.0 / 120.0)
	assert_lt(first.steer, 0.2)


func test_steering_reaches_full_lock_promptly() -> void:
	# Smoothing that felt like lag would be worse than none at all.
	var held := _hold(1.0, 60)
	assert_almost_eq(held.steer, 1.0, 0.001)


func test_steering_returns_to_centre_when_released() -> void:
	_hold(1.0, 60)
	var released := _hold(0.0, 60)
	assert_almost_eq(released.steer, 0.0, 0.001)


func test_centring_is_quicker_than_steering_in() -> void:
	assert_gt(Controls.STEER_CENTRE_RATE, Controls.STEER_RATE)


func test_reversing_lock_uses_the_faster_rate() -> void:
	# Crossing back through centre is a correction, and a correction that
	# arrives late has already become a spin.
	_hold(1.0, 60)
	var crossing: DriverInput = _controls._advance(-1.0, 0.0, 0.0, false, 0.1)
	assert_lt(crossing.steer, 1.0 - Controls.STEER_RATE * 0.1 + 0.0001)


func test_pedals_ramp_and_settle() -> void:
	var pressed: DriverInput = null
	for _tick: int in 60:
		pressed = _controls._advance(0.0, 1.0, 0.0, false, 1.0 / 120.0)
	assert_almost_eq(pressed.throttle, 1.0, 0.001)


func test_output_stays_within_range() -> void:
	var extreme: DriverInput = _controls._advance(5.0, 5.0, -5.0, false, 1.0)
	assert_between(extreme.steer, -1.0, 1.0)
	assert_between(extreme.throttle, 0.0, 1.0)
	assert_between(extreme.brake, 0.0, 1.0)


func test_reset_clears_held_state() -> void:
	_hold(1.0, 60)
	_controls.reset()
	var after: DriverInput = _controls._advance(0.0, 0.0, 0.0, false, 1.0 / 120.0)
	assert_eq(after.steer, 0.0)


func test_energy_passes_straight_through() -> void:
	var boosting: DriverInput = _controls._advance(0.0, 0.0, 0.0, true, 0.01)
	assert_true(boosting.energy)
