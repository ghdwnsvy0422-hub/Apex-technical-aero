extends Node3D

const TAG: String = "Sweep"
const TRACK_ID: String = "aurora_speedway"

const DOWNFORCE_AREAS: Array[float] = [2.0, 4.0, 6.0, 8.0, 10.0]
const TARGET_LAPS: int = 2
const TIMEOUT_S: int = 400

var _failures: PackedStringArray = []
var _track: Track
var _line: RacingLine
var _rows: Array[Dictionary] = []


func _ready() -> void:
	var envelopes := await _measure_every_setup()
	if not _build_track():
		_report()
		return
	for downforce_area: float in DOWNFORCE_AREAS:
		await _drive_one(downforce_area, envelopes[downforce_area])
	_print_table()
	_check_tradeoff()
	_report()


func _measure_every_setup() -> Dictionary:
	var envelopes: Dictionary = {}
	for downforce_area: float in DOWNFORCE_AREAS:
		var setup := _setup_for(downforce_area)
		var envelope: PerformanceEnvelope = await PerformanceEnvelope.measure(self, setup)
		envelopes[downforce_area] = envelope
		Log.info(TAG, "downforce %.1f: %s" % [downforce_area, envelope.describe()])
		Log.info(TAG, "downforce %.1f: %s" % [downforce_area, envelope.describe_grip()])
		Log.info(TAG, "downforce %.1f: %s" % [downforce_area, envelope.describe_braking()])
		Log.info(TAG, "downforce %.1f: %s" % [downforce_area, envelope.describe_drive()])
	return envelopes


func _setup_for(downforce_area: float) -> CarSetup:
	var setup := CarSetup.new()
	setup.downforce_area = downforce_area
	return setup


func _build_track() -> bool:
	var source := DataRegistry.get_track(TRACK_ID)
	if source.is_empty():
		_check(false, "track '%s' is missing" % TRACK_ID)
		return false

	_track = TrackCompiler.build(source)
	add_child(_track)
	_track.build()
	_line = RacingLine.from_curve(_track.curve, _track.profile.road_half_width)
	if _line.points.is_empty():
		_check(false, "racing line is empty")
		return false
	return true


func _drive_one(downforce_area: float, envelope: PerformanceEnvelope) -> void:
	envelope.apply_to(_line)
	var run: LapRunner = await LapRunner.run(
		self, _track, _line, _setup_for(downforce_area), _sector_count(), TARGET_LAPS, TIMEOUT_S
	)
	var completed := run.finished(TARGET_LAPS)

	_rows.append({
		"downforce_area": downforce_area,
		"top_speed_kph": envelope.top_speed_kph,
		"lateral_g": envelope.lateral_g,
		"ideal_s": _line.estimated_lap_seconds(),
		"lap_s": run.best_lap_s if completed else 0.0,
		"laps": run.laps_completed,
	})

	if completed:
		Log.info(TAG, "downforce %.1f: ideal %s | driven %s" % [
			downforce_area,
			LapTimer.format_time(_line.estimated_lap_seconds()),
			LapTimer.format_time(run.best_lap_s),
		])
		return
	Log.warn(TAG, "downforce %.1f: did not finish (%d laps in %.0f s)" % [
		downforce_area, run.laps_completed, run.elapsed_s
	])


func _sector_count() -> int:
	return int(DataRegistry.get_track(TRACK_ID).get("sector_count", 3))


func _print_table() -> void:
	if _rows.is_empty():
		return
	var quickest := _quickest()
	Log.info(TAG, "")
	Log.info(TAG, "  downforce   top speed   lateral   ideal lap   driven lap    delta")
	for row: Dictionary in _rows:
		Log.info(TAG, "  %8.1f   %6.0f km/h   %5.2f g   %s   %s   %s" % [
			row["downforce_area"], row["top_speed_kph"], row["lateral_g"],
			LapTimer.format_time(row["ideal_s"]),
			LapTimer.format_time(row["lap_s"]) if _finished(row) else "  DNF    ",
			_delta_column(row, quickest),
		])
	Log.info(TAG, "")


func _delta_column(row: Dictionary, quickest: Dictionary) -> String:
	if not _finished(row):
		return "%d lap(s) only" % row["laps"]
	if quickest.is_empty():
		return ""
	if row["lap_s"] == quickest["lap_s"]:
		return "  ---  <- quickest"
	return "%+6.3f s" % (float(row["lap_s"]) - float(quickest["lap_s"]))


static func _finished(row: Dictionary) -> bool:
	return float(row["lap_s"]) > 0.0


func _finishers() -> Array[Dictionary]:
	var finishers: Array[Dictionary] = []
	for row: Dictionary in _rows:
		if _finished(row):
			finishers.append(row)
	return finishers


func _quickest() -> Dictionary:
	var finishers := _finishers()
	if finishers.is_empty():
		return {}
	var best := finishers[0]
	for row: Dictionary in finishers:
		if row["lap_s"] < best["lap_s"]:
			best = row
	return best


func _quickest_by_ideal() -> Dictionary:
	var best: Dictionary = _rows[0]
	for row: Dictionary in _rows:
		if row["ideal_s"] < best["ideal_s"]:
			best = row
	return best


func _check_tradeoff() -> void:
	if _rows.size() < 2:
		_check(false, "not enough setups measured to judge the trade-off")
		return

	var first: Dictionary = _rows[0]
	var last: Dictionary = _rows[_rows.size() - 1]
	_check(
		last["top_speed_kph"] < first["top_speed_kph"],
		"PRD 27: wing area costs top speed (%.0f -> %.0f km/h)" % [
			first["top_speed_kph"], last["top_speed_kph"]
		]
	)
	_check(
		last["lateral_g"] > first["lateral_g"],
		"PRD 27: wing area buys cornering (%.2f -> %.2f g)" % [
			first["lateral_g"], last["lateral_g"]
		]
	)
	_check_every_setup_completed()
	_check_no_universal_setup()


func _check_every_setup_completed() -> void:
	var missing := _rows.size() - _finishers().size()
	_check(missing == 0, "every measured setup completes a lap (%d did not)" % missing)


func _check_no_universal_setup() -> void:
	if _rows.size() < 3:
		_check(false, "only %d setup(s) measured, too few to rank" % _rows.size())
		return

	var quickest := _quickest_by_ideal()
	var slowest: Dictionary = _rows[0]
	for row: Dictionary in _rows:
		if row["ideal_s"] > slowest["ideal_s"]:
			slowest = row

	var spread: float = float(slowest["ideal_s"]) - float(quickest["ideal_s"])
	Log.info(TAG, "quickest setup: downforce %.1f | %.3f s covers the setups on ideal pace" % [
		quickest["downforce_area"], spread
	])
	_check(spread > 0.2, "the setups are not interchangeable (%.3f s separates them)" % spread)
	_check(
		quickest["downforce_area"] > float(_rows[0]["downforce_area"])
			and quickest["downforce_area"] < float(_rows[_rows.size() - 1]["downforce_area"]),
		"the quickest setup is an interior optimum rather than an extreme (downforce %.1f)"
			% quickest["downforce_area"]
	)


func _report() -> void:
	if _failures.is_empty():
		Log.info(TAG, "Sweep complete")
		get_tree().quit(0)
		return
	Log.error(TAG, "%d sweep check(s) failed" % _failures.size())
	get_tree().quit(1)


func _check(passed: bool, description: String) -> void:
	if passed:
		Log.info(TAG, "PASS  %s" % description)
		return
	_failures.append(description)
	Log.error(TAG, "FAIL  %s" % description)
