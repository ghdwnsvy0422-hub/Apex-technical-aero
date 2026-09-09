extends Node3D

const TAG: String = "LapProbe"
const TRACK_ID: String = "aurora_speedway"

const TARGET_LAPS: int = 2
const TIMEOUT_S: int = 400

const BASELINE_LAP_S: float = 64.467
const LAP_TOLERANCE_S: float = 0.5
const MIN_FLYING_KPH: float = 30.0

var _failures: PackedStringArray = []
var _track: Track
var _line: RacingLine
var _run: LapRunner


func _ready() -> void:
	if not _build_world():
		_report()
		return
	_run = await LapRunner.run(
		self, _track, _line, null, _sector_count(), TARGET_LAPS, TIMEOUT_S
	)
	_report_run()
	_report()


func _sector_count() -> int:
	return int(DataRegistry.get_track(TRACK_ID).get("sector_count", 3))


func _build_world() -> bool:
	var source := DataRegistry.get_track(TRACK_ID)
	if source.is_empty():
		_check(false, "track '%s' is missing" % TRACK_ID)
		return false

	_track = TrackCompiler.build(source)
	add_child(_track)
	_track.build()
	if _track.length() <= 0.0:
		_check(false, "track '%s' compiled to nothing" % TRACK_ID)
		return false

	_line = RacingLine.from_curve(_track.curve, _track.profile.road_half_width)
	if _line.points.is_empty():
		_check(false, "racing line is empty")
		return false

	Log.info(TAG, "%s: %.0f m, ideal lap %s" % [
		TRACK_ID, _track.length(), LapTimer.format_time(_line.estimated_lap_seconds())
	])
	return true


func _report_run() -> void:
	for index: int in _run.lap_times_s.size():
		Log.info(TAG, "lap %d  %s" % [index + 1, LapTimer.format_time(_run.lap_times_s[index])])

	_check(
		_run.finished(TARGET_LAPS),
		"the AI driver completes %d laps (got %d in %.0f s)" % [
			TARGET_LAPS, _run.laps_completed, _run.elapsed_s
		]
	)
	if not _run.finished(TARGET_LAPS):
		return

	_report_lap_time()
	_report_discipline()


func _report_lap_time() -> void:
	var drift := _run.best_lap_s - BASELINE_LAP_S
	Log.info(TAG, "best lap %s | baseline %s | drift %+.3f s" % [
		LapTimer.format_time(_run.best_lap_s), LapTimer.format_time(BASELINE_LAP_S), drift
	])
	_check(
		absf(drift) <= LAP_TOLERANCE_S,
		"best lap stays within %.1f s of the baseline (%+.3f s)" % [LAP_TOLERANCE_S, drift]
	)


func _report_discipline() -> void:
	var kerb_edge := _track.profile.kerb_edge()
	Log.info(TAG, "widest line %.2f m from centre (kerb edge %.2f m) | slowest %.0f km/h" % [
		_run.widest_lateral_m, kerb_edge, _run.slowest_kph
	])
	_check(_run.widest_lateral_m < kerb_edge, "the car never runs past the kerb")
	_check(
		_run.slowest_kph > MIN_FLYING_KPH,
		"the car never crawls or stalls (%.0f km/h)" % _run.slowest_kph
	)
	_check(not _run.wrong_way, "the car never runs backwards")


func _report() -> void:
	if _failures.is_empty():
		Log.info(TAG, "All lap probes passed")
		get_tree().quit(0)
		return
	Log.error(TAG, "%d lap probe(s) failed" % _failures.size())
	get_tree().quit(1)


func _check(passed: bool, description: String) -> void:
	if passed:
		Log.info(TAG, "PASS  %s" % description)
		return
	_failures.append(description)
	Log.error(TAG, "FAIL  %s" % description)
