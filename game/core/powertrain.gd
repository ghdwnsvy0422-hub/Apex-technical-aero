class_name Powertrain
extends RefCounted
## Engine torque curve, gearing, and gear selection.
##
## Pure math so gearing changes (PRD 22 gear ratio slider) can be swept
## headlessly for their effect on lap time rather than judged by feel.

## Engine speed is derived from wheel speed through the gearing, so a car that
## is stationary would sit at 0 rpm and produce no torque. Idle is the floor.
static func engine_rpm(wheel_angular_velocity: float, total_ratio: float, idle_rpm: float) -> float:
	var rpm := absf(wheel_angular_velocity) * total_ratio * 60.0 / TAU
	return maxf(rpm, idle_rpm)


static func total_ratio(gear: int, setup: CarSetup) -> float:
	if gear < 0 or gear >= setup.gear_ratios.size():
		return 0.0
	return setup.gear_ratios[gear] * setup.final_drive


## Fraction of peak torque available at this engine speed, 0..1. Returns 0
## above the limiter so holding a gear too long actually costs drive.
static func torque_fraction(rpm: float, setup: CarSetup) -> float:
	if rpm > setup.engine_max_rpm:
		return 0.0
	var peak := setup.engine_peak_torque_rpm
	var span := maxf(peak - setup.engine_idle_rpm, setup.engine_max_rpm - peak)
	if span <= 0.0:
		return 1.0
	var distance := (rpm - peak) / span
	return clampf(1.0 - 0.55 * distance * distance, 0.0, 1.0)


static func engine_torque(rpm: float, throttle: float, setup: CarSetup) -> float:
	return setup.engine_peak_torque * torque_fraction(rpm, setup) * clampf(throttle, 0.0, 1.0)


## Torque delivered to the driven axle, before it is split between wheels.
static func axle_torque(rpm: float, throttle: float, gear: int, setup: CarSetup) -> float:
	var ratio := total_ratio(gear, setup)
	if ratio <= 0.0:
		return 0.0
	return engine_torque(rpm, throttle, setup) * ratio * setup.drivetrain_efficiency


## Upshifts near the limiter and downshifts when the engine falls out of its
## range. The thresholds must not overlap or the box would oscillate between
## two gears every tick.
static func select_gear(current_gear: int, rpm: float, setup: CarSetup) -> int:
	var top_gear := setup.gear_ratios.size() - 1
	if rpm >= setup.shift_up_rpm and current_gear < top_gear:
		return current_gear + 1
	if rpm <= setup.shift_down_rpm and current_gear > 0:
		return current_gear - 1
	return current_gear


static func brake_torque(brake: float, is_front: bool, setup: CarSetup) -> float:
	var share := setup.brake_balance if is_front else 1.0 - setup.brake_balance
	# Balance is an axle share; each axle has two wheels.
	return setup.max_brake_torque * share * 0.5 * clampf(brake, 0.0, 1.0)
