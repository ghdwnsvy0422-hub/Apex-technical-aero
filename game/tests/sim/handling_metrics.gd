class_name HandlingMetrics
extends RefCounted

const LOG_TAG: String = "Handling"
const TICK_RATE: int = 120

const ENTRY_SPEED_KPH: float = 150.0
const ENTRY_TIMEOUT_S: int = 30
const SETTLE_S: float = 1.5
const STEADY_WINDOW_S: float = 0.8

const STEP_STEER: float = 0.45
const STEP_HOLD_S: float = 3.0
const RESPONSE_FRACTION: float = 0.9

const CORNER_STEER: float = 0.30
const CORNER_SETTLE_S: float = 3.5
const CORNER_THROTTLE: float = 0.30
const POWER_STEP_THROTTLE: float = 0.75
const POWER_STEP_HOLD_S: float = 1.5
const POWER_STEPS: Array[float] = [0.40, 0.50, 0.60, 0.70, 0.85, 1.00]
const CONTROL_BODY_SLIP_DEG: float = 15.0

const EXIT_UNWIND_S: float = 1.0
const EXIT_HOLD_S: float = 1.5

const BRAKE_ENTRY_KPH: float = 250.0
const BRAKE_HOLD_S: float = 2.5
const BRAKE_STEER: float = 0.10

const NEUTRAL_BALANCE_BAND_DEG: float = 0.5

var steer_response_s: float = 0.0
var yaw_overshoot: float = 1.0
var slip_balance_deg: float = 0.0
var corner_rotation_ratio: float = 1.0
var power_rotation_gain: float = 1.0
var power_body_slip_deg: float = 0.0
var throttle_headroom: float = 0.0
var exit_body_slip_deg: float = 0.0
var brake_body_slip_deg: float = 0.0


static func measure(host: Node, setup: CarSetup) -> HandlingMetrics:
	var metrics := HandlingMetrics.new()
	var window := int(STEADY_WINDOW_S * TICK_RATE)

	var step := await _run_step_steer(host, setup)
	metrics.steer_response_s = response_time(step, RESPONSE_FRACTION, window, TICK_RATE)
	metrics.yaw_overshoot = overshoot_ratio(step, window)

	var corner := await _run_steady_corner(host, setup, POWER_STEP_THROTTLE)
	metrics.slip_balance_deg = corner.slip_balance_deg
	metrics.corner_rotation_ratio = corner.rotation_ratio
	metrics.power_rotation_gain = corner.power_rotation_gain
	metrics.power_body_slip_deg = corner.power_body_slip_deg

	metrics.throttle_headroom = await _measure_throttle_headroom(host, setup)
	metrics.exit_body_slip_deg = await measure_corner_exit(host, setup)
	metrics.brake_body_slip_deg = await _measure_brake_stability(host, setup)
	return metrics


func describe() -> String:
	return (
		"response %.3f s | overshoot %.2f | balance %+.2f deg (%s) | rotation %.2f"
		+ " | power gain %.2f | power slip %.1f deg | throttle headroom %.0f%%"
		+ " | exit slip %.1f deg | brake slip %.1f deg"
	) % [
		steer_response_s,
		yaw_overshoot,
		slip_balance_deg,
		balance_label(slip_balance_deg),
		corner_rotation_ratio,
		power_rotation_gain,
		power_body_slip_deg,
		throttle_headroom * 100.0,
		exit_body_slip_deg,
		brake_body_slip_deg,
	]


static func balance_label(balance_deg: float) -> String:
	if balance_deg > NEUTRAL_BALANCE_BAND_DEG:
		return "understeer"
	if balance_deg < -NEUTRAL_BALANCE_BAND_DEG:
		return "oversteer"
	return "neutral"


static func steady_value(series: PackedFloat32Array, window: int) -> float:
	if series.is_empty():
		return 0.0
	var count: int = clampi(window, 1, series.size())
	var total: float = 0.0
	for index: int in range(series.size() - count, series.size()):
		total += series[index]
	return total / float(count)


static func response_time(
	series: PackedFloat32Array, fraction: float, window: int, tick_rate: int
) -> float:
	if series.is_empty() or tick_rate <= 0:
		return 0.0
	var target: float = steady_value(series, window) * fraction
	if target <= 0.0:
		return 0.0
	for index: int in series.size():
		if series[index] >= target:
			return float(index) / float(tick_rate)
	return float(series.size()) / float(tick_rate)


static func overshoot_ratio(series: PackedFloat32Array, window: int) -> float:
	var steady: float = steady_value(series, window)
	if steady <= 0.0:
		return 1.0
	var peak: float = 0.0
	for value: float in series:
		peak = maxf(peak, value)
	return peak / steady


static func geometric_curvature(steer_angle: float, wheelbase: float) -> float:
	if wheelbase <= 0.0:
		return 0.0
	return tan(absf(steer_angle)) / wheelbase


static func rotation_ratio_of(actual_curvature: float, geometric: float) -> float:
	if geometric <= 0.0:
		return 1.0
	return actual_curvature / geometric


static func front_steer_angle(car: CarBody) -> float:
	for wheel: Wheel in car.wheels:
		if wheel.is_front:
			return absf(wheel.steer_angle)
	return 0.0


static func body_slip_deg(car: CarBody) -> float:
	var velocity := car.linear_velocity
	velocity.y = 0.0
	if velocity.length() < 1.0:
		return 0.0
	var forward := car.global_transform.basis * Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		return 0.0
	return rad_to_deg(absf(forward.normalized().angle_to(velocity.normalized())))


static func axle_slip_balance_deg(car: CarBody) -> float:
	var front: float = 0.0
	var front_count: int = 0
	var rear: float = 0.0
	var rear_count: int = 0
	for wheel: Wheel in car.wheels:
		if not wheel.grounded:
			continue
		if wheel.is_front:
			front += absf(wheel.slip_angle)
			front_count += 1
		else:
			rear += absf(wheel.slip_angle)
			rear_count += 1
	if front_count == 0 or rear_count == 0:
		return 0.0
	return rad_to_deg(front / front_count - rear / rear_count)


class CornerResult extends RefCounted:
	var slip_balance_deg: float = 0.0
	var rotation_ratio: float = 1.0
	var power_rotation_gain: float = 1.0
	var power_body_slip_deg: float = 0.0


static func _run_step_steer(host: Node, setup: CarSetup) -> PackedFloat32Array:
	var harness := _spawn(host, setup)
	if not await _accelerate_to(host, harness, ENTRY_SPEED_KPH):
		_despawn(host, harness)
		return PackedFloat32Array()

	await harness.drive(
		DriverInput.create(CORNER_THROTTLE, 0.0, 0.0), int(SETTLE_S * TICK_RATE)
	)

	harness.car.input = DriverInput.create(CORNER_THROTTLE, 0.0, STEP_STEER)
	var series := PackedFloat32Array()
	var heading := _heading(harness.car)
	for _tick: int in int(STEP_HOLD_S * TICK_RATE):
		await host.get_tree().physics_frame
		var now := _heading(harness.car)
		series.append(absf(angle_difference(heading, now)) * TICK_RATE)
		heading = now

	_despawn(host, harness)
	return series


static func _measure_throttle_headroom(host: Node, setup: CarSetup) -> float:
	var headroom: float = 0.0
	for throttle: float in POWER_STEPS:
		var corner := await _run_steady_corner(host, setup, throttle)
		if corner.power_body_slip_deg > CONTROL_BODY_SLIP_DEG:
			break
		headroom = throttle
	Log.info(LOG_TAG, "throttle headroom at the cornering limit: %.0f%%" % [headroom * 100.0])
	return headroom


static func _run_steady_corner(
	host: Node, setup: CarSetup, power_throttle: float
) -> CornerResult:
	var result := CornerResult.new()
	var harness := _spawn(host, setup)
	if not await _accelerate_to(host, harness, ENTRY_SPEED_KPH):
		_despawn(host, harness)
		return result

	await harness.drive(
		DriverInput.create(CORNER_THROTTLE, 0.0, CORNER_STEER),
		int(CORNER_SETTLE_S * TICK_RATE)
	)

	result.slip_balance_deg = await _average_slip_balance(host, harness, STEADY_WINDOW_S)
	result.rotation_ratio = await _average_rotation_ratio(host, harness, STEADY_WINDOW_S)
	var entry_kph := harness.car.speed_kph()

	harness.car.input = DriverInput.create(power_throttle, 0.0, CORNER_STEER)
	result.power_body_slip_deg = await _peak_body_slip(host, harness, POWER_STEP_HOLD_S)
	var after := await _average_rotation_ratio(host, harness, STEADY_WINDOW_S)

	Log.info(
		LOG_TAG,
		"steady corner: %.0f -> %.0f km/h | throttle %.0f%% | rotation %.2f -> %.2f | body slip peak %.1f deg" % [
			entry_kph, harness.car.speed_kph(), power_throttle * 100.0,
			result.rotation_ratio, after, result.power_body_slip_deg
		]
	)
	_despawn(host, harness)
	if result.rotation_ratio > 0.0:
		result.power_rotation_gain = after / result.rotation_ratio
	return result


static func exit_blend(elapsed_s: float, unwind_s: float) -> float:
	if unwind_s <= 0.0:
		return 1.0
	return clampf(elapsed_s / unwind_s, 0.0, 1.0)


static func measure_corner_exit(host: Node, setup: CarSetup) -> float:
	var harness := _spawn(host, setup)
	if not await _accelerate_to(host, harness, ENTRY_SPEED_KPH):
		_despawn(host, harness)
		return 0.0

	await harness.drive(
		DriverInput.create(CORNER_THROTTLE, 0.0, CORNER_STEER),
		int(CORNER_SETTLE_S * TICK_RATE)
	)

	var entry_kph := harness.car.speed_kph()
	var peak: float = 0.0
	for tick: int in int((EXIT_UNWIND_S + EXIT_HOLD_S) * TICK_RATE):
		var blend := exit_blend(float(tick) / TICK_RATE, EXIT_UNWIND_S)
		harness.car.input = DriverInput.create(
			lerpf(CORNER_THROTTLE, 1.0, blend),
			0.0,
			lerpf(CORNER_STEER, 0.0, blend)
		)
		await host.get_tree().physics_frame
		peak = maxf(peak, body_slip_deg(harness.car))

	Log.info(
		LOG_TAG,
		"corner exit: %.0f -> %.0f km/h | body slip peak %.1f deg" % [
			entry_kph, harness.car.speed_kph(), peak
		]
	)
	_despawn(host, harness)
	return peak


static func _measure_brake_stability(host: Node, setup: CarSetup) -> float:
	var harness := _spawn(host, setup)
	if not await _accelerate_to(host, harness, BRAKE_ENTRY_KPH):
		_despawn(host, harness)
		return 0.0

	var entry_kph := harness.car.speed_kph()
	harness.car.input = DriverInput.create(0.0, 1.0, BRAKE_STEER)
	var peak := await _peak_body_slip(host, harness, BRAKE_HOLD_S)

	Log.info(
		LOG_TAG,
		"braking: %.0f -> %.0f km/h | body slip peak %.1f deg" % [
			entry_kph, harness.car.speed_kph(), peak
		]
	)
	_despawn(host, harness)
	return peak


static func _accelerate_to(host: Node, harness: DriveHarness, target_kph: float) -> bool:
	await harness.coast(TICK_RATE)
	for tick: int in ENTRY_TIMEOUT_S * TICK_RATE:
		var elapsed := float(tick) / TICK_RATE
		harness.car.input = DriverInput.create(
			PerformanceEnvelope.launch_throttle(elapsed), 0.0, 0.0
		)
		await host.get_tree().physics_frame
		if harness.car.speed_kph() >= target_kph:
			return true
	return false


static func _average_rotation_ratio(host: Node, harness: DriveHarness, seconds: float) -> float:
	var samples: int = int(seconds * TICK_RATE)
	if samples <= 0:
		return 1.0
	var heading := _heading(harness.car)
	var total: float = 0.0
	for _tick: int in samples:
		await host.get_tree().physics_frame
		var now := _heading(harness.car)
		var yaw_rate := absf(angle_difference(heading, now)) * TICK_RATE
		heading = now
		var curvature := yaw_rate / maxf(harness.car.linear_velocity.length(), 1.0)
		var geometric := geometric_curvature(
			front_steer_angle(harness.car), harness.car.setup.wheelbase
		)
		total += rotation_ratio_of(curvature, geometric)
	return total / float(samples)


static func _average_slip_balance(host: Node, harness: DriveHarness, seconds: float) -> float:
	var samples: int = int(seconds * TICK_RATE)
	if samples <= 0:
		return 0.0
	var total: float = 0.0
	for _tick: int in samples:
		await host.get_tree().physics_frame
		total += axle_slip_balance_deg(harness.car)
	return total / float(samples)


static func _peak_body_slip(host: Node, harness: DriveHarness, seconds: float) -> float:
	var peak: float = 0.0
	for _tick: int in int(seconds * TICK_RATE):
		await host.get_tree().physics_frame
		peak = maxf(peak, body_slip_deg(harness.car))
	return peak


static func _heading(car: CarBody) -> float:
	var forward := car.global_transform.basis * Vector3.FORWARD
	return atan2(forward.x, forward.z)


static func _spawn(host: Node, setup: CarSetup) -> DriveHarness:
	var harness := DriveHarness.new(setup)
	host.add_child(harness)
	return harness


static func _despawn(host: Node, harness: DriveHarness) -> void:
	host.remove_child(harness)
	harness.queue_free()
