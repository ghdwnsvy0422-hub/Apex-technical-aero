extends Node3D
## Drives the car headlessly and checks the resulting behaviour against
## physically plausible bounds.
##
## Unit tests can prove the tyre curve peaks where it should, but only a real
## simulation shows whether the assembled car stands up, accelerates, stops and
## turns. Bounds are wide on purpose: this catches "the car cannot drive", not
## "the car is 0.2 s off the pace". Lap-time regression arrives in Phase 1.7.
##
## Run with: tools/godot.sh --headless --fixed-fps 30 --path game -- --sim

const TICK_RATE: int = 120
const GRAVITY: float = 9.8
const TAG: String = "Probe"

var _failures: PackedStringArray = []


func _ready() -> void:
	await _probe_settling()
	await _probe_acceleration()
	await _probe_braking()
	await _probe_cornering()
	await _probe_downforce_tradeoff()
	_report()


func _probe_settling() -> void:
	var harness := _spawn()
	await harness.coast(2 * TICK_RATE)

	_check(
		harness.car.grounded_wheel_count() == 4,
		"rests on all four wheels (got %d)" % harness.car.grounded_wheel_count()
	)

	var carried := harness.total_wheel_load()
	var weight := harness.car.setup.mass * GRAVITY
	_check(
		absf(carried - weight) / weight < 0.12,
		"suspension carries the car's weight (%.0f N vs %.0f N)" % [carried, weight]
	)

	var setup := harness.car.setup
	var expected_sag := setup.mass * GRAVITY / (4.0 * setup.suspension_stiffness)
	var expected_y := setup.contact_depth() - expected_sag
	_check(
		absf(harness.car.global_position.y - expected_y) < 0.04,
		"settles at its static ride height (%.3f m, expected %.3f m)" % [
			harness.car.global_position.y, expected_y
		]
	)

	_despawn(harness)


func _probe_acceleration() -> void:
	var harness := _spawn()
	await harness.coast(TICK_RATE)

	var to_100 := -1.0
	var to_200 := -1.0
	var peak_slip := 0.0
	for tick: int in 15 * TICK_RATE:
		var elapsed := float(tick) / TICK_RATE
		harness.car.input = DriverInput.create(_launch_throttle(elapsed), 0.0, 0.0)
		await get_tree().physics_frame

		for wheel: Wheel in harness.car.wheels:
			if wheel.is_driven:
				peak_slip = maxf(peak_slip, wheel.slip_ratio)

		var kph := harness.car.speed_kph()
		if to_100 < 0.0 and kph >= 100.0:
			to_100 = elapsed
		if to_200 < 0.0 and kph >= 200.0:
			to_200 = elapsed

	Log.info(TAG, "0-100 %.2fs | 0-200 %.2fs | after 15s %.0f km/h | peak driven slip %.2f" % [
		to_100, to_200, harness.car.speed_kph(), peak_slip
	])

	_check(to_100 > 1.0 and to_100 < 5.0, "reaches 100 km/h in a plausible time (%.2fs)" % to_100)
	_check(to_200 > 0.0 and to_200 < 11.0, "reaches 200 km/h in a plausible time (%.2fs)" % to_200)
	_check(harness.car.gear > 2, "gearbox works up the box (gear %d)" % harness.car.gear)
	_check(peak_slip > 0.05, "throttle can still spin the driven wheels (%.2f)" % peak_slip)

	_despawn(harness)


## A 1000 hp car has far more torque than grip in the lower gears, so pinning
## the throttle from rest simply sits on the rev limiter in wheelspin. Real
## launches feed it in; measuring with full throttle would test the tyre's
## slip tail rather than the car's acceleration.
func _launch_throttle(elapsed: float) -> float:
	return clampf(0.25 + elapsed / 2.5, 0.0, 1.0)


func _probe_braking() -> void:
	var harness := _spawn()
	await harness.coast(TICK_RATE)
	await harness.drive(DriverInput.create(1.0, 0.0, 0.0), 8 * TICK_RATE)

	var entry_speed := harness.car.linear_velocity.length()
	harness.car.input = DriverInput.create(0.0, 1.0, 0.0)
	var ticks := 0
	while harness.car.linear_velocity.length() > entry_speed * 0.25 and ticks < 10 * TICK_RATE:
		await get_tree().physics_frame
		ticks += 1

	var elapsed := float(ticks) / TICK_RATE
	var deceleration := (entry_speed - harness.car.linear_velocity.length()) / maxf(elapsed, 0.001)
	Log.info(TAG, "braking from %.0f km/h: %.2f s, mean %.1f m/s^2 (%.1f g)" % [
		entry_speed * 3.6, elapsed, deceleration, deceleration / GRAVITY
	])

	_check(deceleration > 10.0, "brakes harder than 1 g on average")
	_check(deceleration < 80.0, "braking is not physically absurd")

	_despawn(harness)


func _probe_cornering() -> void:
	var harness := _spawn()
	await harness.coast(TICK_RATE)
	await harness.drive(DriverInput.create(1.0, 0.0, 0.0), 3 * TICK_RATE)

	var start_heading := _heading(harness.car)
	var start_x := harness.car.global_position.x
	await harness.drive(DriverInput.create(0.45, 0.0, 1.0), 4 * TICK_RATE)
	var turned := absf(rad_to_deg(angle_difference(start_heading, _heading(harness.car))))
	var drift := harness.car.global_position.x - start_x

	var upright := harness.car.global_transform.basis.y.dot(Vector3.UP)
	Log.info(TAG, "cornering: turned %.0f deg, drift %+.1f m, upright %.2f" % [
		turned, drift, upright
	])

	_check(turned > 20.0, "steering input actually turns the car (%.0f deg)" % turned)
	# The car starts facing -Z, so a right-hand input must carry it towards +X.
	# Checking only the magnitude of the turn would miss axles fitted back to
	# front, which steers the car with its rear wheels.
	_check(drift > 1.0, "steering right sends the car right (%+.1f m)" % drift)
	_check(upright > 0.7, "car stays upright through the corner")

	_despawn(harness)


## PRD 27: wing area bought for cornering must be paid for on the straights.
## If this ever stops holding, every track collapses to one optimal setup.
func _probe_downforce_tradeoff() -> void:
	var low: float = await _top_speed_with_downforce(1.5)
	var high: float = await _top_speed_with_downforce(6.0)
	Log.info(TAG, "top speed: low downforce %.0f km/h | high downforce %.0f km/h" % [low, high])
	_check(
		low > high + 10.0,
		"more downforce costs top speed (%.0f vs %.0f km/h)" % [low, high]
	)


## Runs until the car stops gaining speed rather than for a fixed time, since
## a time-boxed run measures acceleration and would rank the grippier car
## first - the opposite of what this probe exists to check.
func _top_speed_with_downforce(downforce_area: float) -> float:
	var setup := CarSetup.new()
	setup.downforce_area = downforce_area
	var harness := _spawn(setup)
	await harness.coast(TICK_RATE)

	harness.car.input = DriverInput.create(1.0, 0.0, 0.0)
	var previous := 0.0
	var speed := 0.0
	for tick: int in 120 * TICK_RATE:
		await get_tree().physics_frame
		if tick % TICK_RATE != 0:
			continue
		speed = harness.car.speed_kph()
		if tick > 0 and absf(speed - previous) < 0.3:
			break
		previous = speed

	_despawn(harness)
	return speed


func _heading(car: CarBody) -> float:
	var forward := car.global_transform.basis * Vector3.FORWARD
	return atan2(forward.x, forward.z)


func _spawn(setup: CarSetup = null) -> DriveHarness:
	var harness := DriveHarness.new(setup)
	add_child(harness)
	return harness


func _despawn(harness: DriveHarness) -> void:
	remove_child(harness)
	harness.queue_free()


func _check(passed: bool, description: String) -> void:
	if passed:
		Log.info(TAG, "PASS  %s" % description)
		return
	_failures.append(description)
	Log.error(TAG, "FAIL  %s" % description)


func _report() -> void:
	if _failures.is_empty():
		Log.info(TAG, "All physics probes passed")
		get_tree().quit(0)
		return
	Log.error(TAG, "%d physics probe(s) failed" % _failures.size())
	get_tree().quit(1)
