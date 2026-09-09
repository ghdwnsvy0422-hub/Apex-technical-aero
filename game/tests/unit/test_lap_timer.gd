extends GutTest

const Registry := preload("res://core/data_registry.gd")

const SHIPPED_TRACK := "res://data/tracks/aurora_speedway.json"
const LAP_LENGTH: float = 300.0
const SECTORS: int = 3

var _offset: float = 0.0
var _now: float = 0.0


func before_each() -> void:
	_offset = 0.0
	_now = 0.0


func _timer(offset: float = 0.0) -> LapTimer:
	var timer := LapTimer.create(LAP_LENGTH, SECTORS)
	_offset = offset
	timer.update(_offset, _now)
	return timer


func _drive(
	timer: LapTimer, distance: float, step_m: float, dt: float, reverse: bool = false
) -> void:
	var travelled := 0.0
	while travelled < distance - 0.000001:
		var chunk := minf(step_m, distance - travelled)
		_offset = fposmod((_offset - chunk) if reverse else (_offset + chunk), LAP_LENGTH)
		travelled += chunk
		_now += dt
		timer.update(_offset, _now)


func test_a_full_lap_completes_with_one_lap_and_three_splits() -> void:
	var timer := _timer()
	watch_signals(timer)
	_drive(timer, LAP_LENGTH, 10.0, 0.1)

	assert_eq(timer.laps_completed, 1)
	assert_eq(timer.sector, 0)
	assert_signal_emit_count(timer, "lap_completed", 1)
	assert_signal_emit_count(timer, "sector_completed", SECTORS)


func test_sector_splits_add_up_to_the_lap_time() -> void:
	var timer := _timer()
	_drive(timer, LAP_LENGTH, 10.0, 0.1)

	var total := 0.0
	for split: float in timer.last_sector_s:
		assert_almost_eq(split, 1.0, 0.0001)
		total += split
	assert_almost_eq(timer.last_lap_s, total, 0.0001)


func test_sector_index_advances_with_progress() -> void:
	var timer := _timer()
	_drive(timer, 120.0, 10.0, 0.1)
	assert_eq(timer.sector, 1)
	_drive(timer, 100.0, 10.0, 0.1)
	assert_eq(timer.sector, 2)


func test_the_offset_wrapping_past_the_line_counts_as_forward_progress() -> void:
	var timer := _timer(LAP_LENGTH - 5.0)
	timer.update(5.0, 0.1)
	assert_almost_eq(timer.progress_m(), 10.0, 0.0001)
	assert_false(timer.wrong_way)


func test_reversing_over_the_line_does_not_hand_out_a_second_lap() -> void:
	var timer := _timer()
	watch_signals(timer)
	_drive(timer, LAP_LENGTH + 10.0, 10.0, 0.1)
	assert_eq(timer.laps_completed, 1, "the honest lap")

	_drive(timer, 30.0, 10.0, 0.1, true)
	assert_eq(timer.laps_completed, 0, "reversing back over the line undoes it")

	_drive(timer, 40.0, 10.0, 0.1)
	assert_eq(timer.laps_completed, 1, "crossing again returns to one lap, not two")
	assert_signal_emit_count(timer, "lap_completed", 1)


func test_a_lap_driven_backwards_over_the_line_cannot_become_the_best_lap() -> void:
	var timer := _timer()
	_drive(timer, LAP_LENGTH + 10.0, 10.0, 0.1)
	var honest_best := timer.best_lap_s
	assert_almost_eq(honest_best, 3.0, 0.0001)

	_drive(timer, 30.0, 10.0, 0.1, true)
	_drive(timer, 40.0, 10.0, 0.1)

	assert_almost_eq(timer.best_lap_s, honest_best, 0.0001, "the 0.3 s re-crossing is not a lap")
	assert_almost_eq(timer.last_lap_s, honest_best, 0.0001)


func test_wrong_way_raises_after_a_sustained_reverse_and_clears_on_recovery() -> void:
	var timer := _timer(150.0)
	watch_signals(timer)

	_drive(timer, LapTimer.WRONG_WAY_DISTANCE_M - 5.0, 5.0, 0.1, true)
	assert_false(timer.wrong_way, "a short slide backwards is not a wrong way")

	_drive(timer, 10.0, 5.0, 0.1, true)
	assert_true(timer.wrong_way)
	assert_false(timer.lap_valid, "the lap is spoiled once the car turns around")

	_drive(timer, LapTimer.RECOVERY_DISTANCE_M + 2.0, 2.0, 0.1)
	assert_false(timer.wrong_way)
	assert_signal_emit_count(timer, "wrong_way_changed", 2)


func test_the_quickest_lap_is_kept() -> void:
	var timer := _timer()
	_drive(timer, LAP_LENGTH, 10.0, 0.1)
	assert_almost_eq(timer.best_lap_s, 3.0, 0.0001)

	_drive(timer, LAP_LENGTH, 10.0, 0.05)
	assert_almost_eq(timer.last_lap_s, 1.5, 0.0001)
	assert_almost_eq(timer.best_lap_s, 1.5, 0.0001)

	_drive(timer, LAP_LENGTH, 10.0, 0.2)
	assert_almost_eq(timer.last_lap_s, 6.0, 0.0001)
	assert_almost_eq(timer.best_lap_s, 1.5, 0.0001, "a slower lap does not replace the best")


func test_a_track_without_a_length_is_ignored() -> void:
	var timer := LapTimer.create(0.0, SECTORS)
	timer.update(10.0, 1.0)
	assert_false(timer.started)
	assert_eq(timer.laps_completed, 0)


func test_one_lap_around_the_shipped_track() -> void:
	var curve := TrackCompiler.curve_from(Registry.read_json(SHIPPED_TRACK) as Dictionary)
	var length := curve.get_baked_length()
	var timer := LapTimer.create(length, SECTORS)
	timer.update(0.0, 0.0)

	var travelled := 0.0
	var now := 0.0
	var worst_offset_error := 0.0
	while travelled < length:
		travelled = minf(travelled + 5.0, length)
		now += 0.1
		var expected := fposmod(travelled, length)
		var recovered := curve.get_closest_offset(curve.sample_baked(expected))
		worst_offset_error = maxf(worst_offset_error, absf(_wrapped(recovered - expected, length)))
		timer.update(recovered, now)

	assert_lt(worst_offset_error, 5.0, "the circuit never runs close enough to itself")
	assert_eq(timer.laps_completed, 1)
	assert_false(timer.wrong_way)
	assert_true(timer.lap_valid)
	assert_almost_eq(timer.last_lap_s, now, 0.2)


func _wrapped(value: float, length: float) -> float:
	var half := length * 0.5
	if value > half:
		return value - length
	if value < -half:
		return value + length
	return value


func test_lap_time_formatting() -> void:
	assert_eq(LapTimer.format_time(0.0), "--:--.---")
	assert_eq(LapTimer.format_time(76.5), "1:16.500")
	assert_eq(LapTimer.format_time(6.5), "0:06.500")
