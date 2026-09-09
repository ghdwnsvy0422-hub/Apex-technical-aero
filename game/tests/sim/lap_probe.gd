extends Node3D

const TAG: String = "LapProbe"
const TICK_RATE: int = 120
const TRACK_ID: String = "aurora_speedway"

const SETTLE_TICKS: int = TICK_RATE
const TARGET_LAPS: int = 2
const TIMEOUT_TICKS: int = 400 * TICK_RATE

const BASELINE_LAP_S: float = 64.467
const LAP_TOLERANCE_S: float = 0.5

var _failures: PackedStringArray = []
var _track: Track
var _line: RacingLine
var _car: CarBody
var _timer: LapTimer
var _driver: AiDriver
var _widest_lateral_m: float = 0.0
var _slowest_kph: float = INF


func _ready() -> void:
	if not _build_world():
		_report()
		return
	await _run_laps()
	_report()


func _build_world() -> bool:
	var source := DataRegistry.get_track(TRACK_ID)
	if source.is_empty():
		_fail("track '%s' is missing" % TRACK_ID)
		return false

	_track = TrackCompiler.build(source)
	add_child(_track)
	_track.build()
	if _track.length() <= 0.0:
		_fail("track '%s' compiled to nothing" % TRACK_ID)
		return false

	_line = RacingLine.from_curve(_track.curve, _track.profile.road_half_width)
	if _line.points.is_empty():
		_fail("racing line is empty")
		return false

	_car = CarBody.new()
	_car.transform = _track.start_transform(_car.setup.contact_depth() + 0.10)
	add_child(_car)

	_timer = LapTimer.create(_track.length(), int(source.get("sector_count", 3)))
	_driver = AiDriver.create(_line, _track.curve)

	Log.info(TAG, "%s: %.0f m, ideal lap %s" % [
		TRACK_ID, _track.length(), LapTimer.format_time(_line.estimated_lap_seconds())
	])
	return true


func _run_laps() -> void:
	_car.input = DriverInput.new()
	for _tick: int in SETTLE_TICKS:
		await get_tree().physics_frame

	_timer.start(_driver.centreline_offset(_car.global_position), 0.0)
	_timer.lap_completed.connect(_on_lap_completed)

	var ticks := 0
	while _timer.laps_completed < TARGET_LAPS and ticks < TIMEOUT_TICKS:
		_car.input = _driver.input_for(_car.global_transform, _car.linear_velocity)
		await get_tree().physics_frame
		ticks += 1
		_observe(float(ticks) / TICK_RATE)

	_check(
		_timer.laps_completed >= TARGET_LAPS,
		"the AI driver completes %d laps (got %d in %.0f s)" % [
			TARGET_LAPS, _timer.laps_completed, float(ticks) / TICK_RATE
		]
	)


func _observe(elapsed_s: float) -> void:
	_timer.update(_driver.centreline_offset(_car.global_position), elapsed_s)
	if _timer.laps_completed < 1:
		return

	var here := _car.global_position
	var nearest := _track.curve.get_closest_point(here)
	_widest_lateral_m = maxf(_widest_lateral_m, Vector2(here.x - nearest.x, here.z - nearest.z).length())
	_slowest_kph = minf(_slowest_kph, _car.speed_kph())


func _on_lap_completed(lap: int, seconds: float) -> void:
	Log.info(TAG, "lap %d  %s" % [lap, LapTimer.format_time(seconds)])


func _report() -> void:
	if _timer != null and _timer.laps_completed >= TARGET_LAPS:
		_report_lap_time()
		_report_discipline()

	if _failures.is_empty():
		Log.info(TAG, "All lap probes passed")
		get_tree().quit(0)
		return
	Log.error(TAG, "%d lap probe(s) failed" % _failures.size())
	get_tree().quit(1)


func _report_lap_time() -> void:
	var best := _timer.best_lap_s
	var drift := best - BASELINE_LAP_S
	Log.info(TAG, "best lap %s | baseline %s | drift %+.3f s" % [
		LapTimer.format_time(best), LapTimer.format_time(BASELINE_LAP_S), drift
	])
	_check(
		absf(drift) <= LAP_TOLERANCE_S,
		"best lap stays within %.1f s of the baseline (%+.3f s)" % [LAP_TOLERANCE_S, drift]
	)


func _report_discipline() -> void:
	var kerb_edge := _track.profile.kerb_edge()
	Log.info(TAG, "widest line %.2f m from centre (kerb edge %.2f m) | slowest %.0f km/h" % [
		_widest_lateral_m, kerb_edge, _slowest_kph
	])
	_check(_widest_lateral_m < kerb_edge, "the car never runs past the kerb")
	_check(_slowest_kph > 30.0, "the car never crawls or stalls (%.0f km/h)" % _slowest_kph)
	_check(not _timer.wrong_way, "the car never runs backwards")


func _fail(description: String) -> void:
	_check(false, description)


func _check(passed: bool, description: String) -> void:
	if passed:
		Log.info(TAG, "PASS  %s" % description)
		return
	_failures.append(description)
	Log.error(TAG, "FAIL  %s" % description)
