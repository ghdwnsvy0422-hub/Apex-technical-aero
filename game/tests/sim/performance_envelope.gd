class_name PerformanceEnvelope
extends RefCounted

const TICK_RATE: int = 120
const GRAVITY: float = 9.8

const PLATEAU_TIMEOUT_S: int = 90
const PLATEAU_TOLERANCE_KPH: float = 0.3
const LAUNCH_RAMP_S: float = 2.5

const ACCELERATION_FROM_KPH: float = 100.0
const ACCELERATION_TO_KPH: float = 200.0
const ACCELERATION_REFERENCE_KPH: float = 150.0
const BRAKING_ENTRY_S: int = 8
const BRAKING_FLOOR: float = 0.25
const SKIDPAD_ENTRY_KPH: float = 180.0
const SKIDPAD_SETTLE_S: float = 2.0
const SKIDPAD_MEASURE_S: float = 2.0

var top_speed_kph: float = 0.0
var lateral_g: float = 0.0
var braking_g: float = 0.0
var acceleration_g: float = 0.0
var lateral_reference_speed_mps: float = 0.0
var aero_load_ratio: float = 0.0
var load_sensitivity: float = RacingLine.DEFAULT_LOAD_SENSITIVITY
var acceleration_reference_speed_mps: float = 0.0


static func measure(host: Node, setup: CarSetup) -> PerformanceEnvelope:
	var envelope := PerformanceEnvelope.new()
	envelope.top_speed_kph = await _measure_top_speed(host, setup)
	envelope.acceleration_g = await _measure_acceleration(host, setup)
	envelope.braking_g = await _measure_braking(host, setup)

	var skidpad := await _measure_lateral(host, setup, SKIDPAD_ENTRY_KPH)
	envelope.lateral_g = sample_lateral_g(skidpad)
	envelope.lateral_reference_speed_mps = sample_speed_mps(skidpad)
	envelope.aero_load_ratio = Aero.load_ratio_per_speed_squared(setup, GRAVITY)
	envelope.load_sensitivity = setup.load_sensitivity
	envelope.acceleration_reference_speed_mps = ACCELERATION_REFERENCE_KPH / 3.6
	return envelope


static func sample_lateral_g(sample: Vector2) -> float:
	return sample.x


static func sample_speed_mps(sample: Vector2) -> float:
	return sample.y


func apply_to(line: RacingLine) -> void:
	line.compute_speeds(
		lateral_g, braking_g, acceleration_g, top_speed_kph,
		lateral_reference_speed_mps, aero_load_ratio, load_sensitivity,
		acceleration_reference_speed_mps
	)


func acceleration_g_at(speed_mps: float) -> float:
	return RacingLine.acceleration_at_speed(
		acceleration_g, acceleration_reference_speed_mps, speed_mps, top_speed_kph / 3.6
	)


func lateral_g_at(speed_mps: float) -> float:
	return RacingLine.grip_at_speed(
		lateral_g, lateral_reference_speed_mps, speed_mps, aero_load_ratio, load_sensitivity
	)


func describe() -> String:
	return "top %.0f km/h | lateral %.2f g | braking %.2f g | acceleration %.2f g" % [
		top_speed_kph, lateral_g, braking_g, acceleration_g
	]


func describe_grip() -> String:
	return "lateral %.2f g measured at %.0f km/h | %.2f g at 120 km/h | %.2f g at 280 km/h" % [
		lateral_g, lateral_reference_speed_mps * 3.6,
		lateral_g_at(120.0 / 3.6), lateral_g_at(280.0 / 3.6)
	]


func describe_drive() -> String:
	return "acceleration %.2f g at 150 km/h | %.2f g at 250 km/h | %.2f g at %.0f km/h" % [
		acceleration_g_at(150.0 / 3.6), acceleration_g_at(250.0 / 3.6),
		acceleration_g_at(top_speed_kph / 3.6 - 1.0), top_speed_kph
	]


static func launch_throttle(elapsed_s: float) -> float:
	return clampf(0.25 + elapsed_s / LAUNCH_RAMP_S, 0.0, 1.0)


static func _measure_top_speed(host: Node, setup: CarSetup) -> float:
	var harness := _spawn(host, setup)
	await harness.coast(TICK_RATE)

	harness.car.input = DriverInput.create(1.0, 0.0, 0.0)
	var previous := 0.0
	var speed := 0.0
	for tick: int in PLATEAU_TIMEOUT_S * TICK_RATE:
		await host.get_tree().physics_frame
		if tick % TICK_RATE != 0:
			continue
		speed = harness.car.speed_kph()
		if tick > 0 and absf(speed - previous) < PLATEAU_TOLERANCE_KPH:
			break
		previous = speed

	_despawn(host, harness)
	return speed


static func _measure_acceleration(host: Node, setup: CarSetup) -> float:
	var harness := _spawn(host, setup)
	await harness.coast(TICK_RATE)

	var entered_at := -1.0
	var left_at := -1.0
	for tick: int in 30 * TICK_RATE:
		var elapsed := float(tick) / TICK_RATE
		harness.car.input = DriverInput.create(launch_throttle(elapsed), 0.0, 0.0)
		await host.get_tree().physics_frame

		var kph := harness.car.speed_kph()
		if entered_at < 0.0 and kph >= ACCELERATION_FROM_KPH:
			entered_at = elapsed
		if kph >= ACCELERATION_TO_KPH:
			left_at = elapsed
			break

	_despawn(host, harness)
	if entered_at < 0.0 or left_at <= entered_at:
		return RacingLine.DEFAULT_ACCELERATION_G

	var gained := (ACCELERATION_TO_KPH - ACCELERATION_FROM_KPH) / 3.6
	return gained / (left_at - entered_at) / GRAVITY


static func _measure_braking(host: Node, setup: CarSetup) -> float:
	var harness := _spawn(host, setup)
	await harness.coast(TICK_RATE)
	await harness.drive(DriverInput.create(1.0, 0.0, 0.0), BRAKING_ENTRY_S * TICK_RATE)

	var entry_speed := harness.car.linear_velocity.length()
	harness.car.input = DriverInput.create(0.0, 1.0, 0.0)
	var ticks := 0
	while harness.car.linear_velocity.length() > entry_speed * BRAKING_FLOOR and ticks < 15 * TICK_RATE:
		await host.get_tree().physics_frame
		ticks += 1

	var elapsed := float(ticks) / TICK_RATE
	var shed := entry_speed - harness.car.linear_velocity.length()
	_despawn(host, harness)
	if elapsed <= 0.0:
		return RacingLine.DEFAULT_BRAKING_G
	return shed / elapsed / GRAVITY


static func _measure_lateral(host: Node, setup: CarSetup, entry_kph: float) -> Vector2:
	var harness := _spawn(host, setup)
	await harness.coast(TICK_RATE)

	for tick: int in 30 * TICK_RATE:
		var elapsed := float(tick) / TICK_RATE
		harness.car.input = DriverInput.create(launch_throttle(elapsed), 0.0, 0.0)
		await host.get_tree().physics_frame
		if harness.car.speed_kph() >= entry_kph:
			break

	var cornering := DriverInput.create(0.35, 0.0, 1.0)
	await harness.drive(cornering, int(SKIDPAD_SETTLE_S * TICK_RATE))

	harness.car.input = cornering
	var heading := _heading(harness.car)
	var samples := 0
	var total := 0.0
	var speed_total := 0.0
	for _tick: int in int(SKIDPAD_MEASURE_S * TICK_RATE):
		await host.get_tree().physics_frame
		var now := _heading(harness.car)
		var yaw_rate := absf(angle_difference(heading, now)) * TICK_RATE
		heading = now
		var speed := harness.car.linear_velocity.length()
		total += speed * yaw_rate
		speed_total += speed
		samples += 1

	_despawn(host, harness)
	if samples == 0:
		return Vector2(RacingLine.DEFAULT_LATERAL_G, entry_kph / 3.6)
	return Vector2(total / float(samples) / GRAVITY, speed_total / float(samples))


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
