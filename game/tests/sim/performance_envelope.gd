class_name PerformanceEnvelope
extends RefCounted

const TICK_RATE: int = 120
const GRAVITY: float = 9.8

const PLATEAU_TIMEOUT_S: int = 90
const PLATEAU_TOLERANCE_KPH: float = 0.3
const LAUNCH_RAMP_S: float = 2.5

const ACCELERATION_FROM_KPH: float = 100.0
const ACCELERATION_TO_KPH: float = 200.0
const BRAKING_ENTRY_S: int = 8
const BRAKING_FLOOR: float = 0.25
const SKIDPAD_ENTRY_KPH: float = 180.0
const SKIDPAD_SETTLE_S: float = 2.0
const SKIDPAD_MEASURE_S: float = 2.0

var top_speed_kph: float = 0.0
var lateral_g: float = 0.0
var braking_g: float = 0.0
var acceleration_g: float = 0.0


static func measure(host: Node, setup: CarSetup) -> PerformanceEnvelope:
	var envelope := PerformanceEnvelope.new()
	envelope.top_speed_kph = await _measure_top_speed(host, setup)
	envelope.acceleration_g = await _measure_acceleration(host, setup)
	envelope.braking_g = await _measure_braking(host, setup)
	envelope.lateral_g = await _measure_lateral(host, setup)
	return envelope


func apply_to(line: RacingLine) -> void:
	line.compute_speeds(lateral_g, braking_g, acceleration_g, top_speed_kph)


func describe() -> String:
	return "top %.0f km/h | lateral %.2f g | braking %.2f g | acceleration %.2f g" % [
		top_speed_kph, lateral_g, braking_g, acceleration_g
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


static func _measure_lateral(host: Node, setup: CarSetup) -> float:
	var harness := _spawn(host, setup)
	await harness.coast(TICK_RATE)

	for tick: int in 30 * TICK_RATE:
		var elapsed := float(tick) / TICK_RATE
		harness.car.input = DriverInput.create(launch_throttle(elapsed), 0.0, 0.0)
		await host.get_tree().physics_frame
		if harness.car.speed_kph() >= SKIDPAD_ENTRY_KPH:
			break

	var cornering := DriverInput.create(0.35, 0.0, 1.0)
	await harness.drive(cornering, int(SKIDPAD_SETTLE_S * TICK_RATE))

	harness.car.input = cornering
	var heading := _heading(harness.car)
	var samples := 0
	var total := 0.0
	for _tick: int in int(SKIDPAD_MEASURE_S * TICK_RATE):
		await host.get_tree().physics_frame
		var now := _heading(harness.car)
		var yaw_rate := absf(angle_difference(heading, now)) * TICK_RATE
		heading = now
		total += harness.car.linear_velocity.length() * yaw_rate
		samples += 1

	_despawn(host, harness)
	if samples == 0:
		return RacingLine.DEFAULT_LATERAL_G
	return total / float(samples) / GRAVITY


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
