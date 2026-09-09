class_name LapTimer
extends RefCounted

signal lap_completed(lap: int, seconds: float)
signal sector_completed(sector: int, seconds: float)
signal wrong_way_changed(active: bool)

const WRONG_WAY_DISTANCE_M: float = 25.0
const RECOVERY_DISTANCE_M: float = 10.0

var lap_length_m: float = 0.0
var sector_count: int = 3
var laps_completed: int = 0
var sector: int = 0
var last_lap_s: float = 0.0
var best_lap_s: float = 0.0
var last_sector_s: PackedFloat32Array = PackedFloat32Array()
var wrong_way: bool = false
var lap_valid: bool = true
var started: bool = false

var _progress_m: float = 0.0
var _previous_offset_m: float = 0.0
var _sectors_passed: int = 0
var _lap_start_s: float = 0.0
var _sector_start_s: float = 0.0
var _now_s: float = 0.0
var _backward_m: float = 0.0
var _forward_m: float = 0.0


static func create(length_m: float, sectors: int) -> LapTimer:
	var timer := LapTimer.new()
	timer.lap_length_m = maxf(length_m, 0.0)
	timer.sector_count = maxi(sectors, 1)
	timer.last_sector_s.resize(timer.sector_count)
	return timer


static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--.---"
	var minutes := int(seconds) / 60
	return "%d:%06.3f" % [minutes, seconds - float(minutes * 60)]


func start(offset_m: float, now_s: float) -> void:
	started = true
	laps_completed = 0
	sector = 0
	wrong_way = false
	lap_valid = true
	_progress_m = 0.0
	_previous_offset_m = offset_m
	_sectors_passed = 0
	_lap_start_s = now_s
	_sector_start_s = now_s
	_now_s = now_s
	_backward_m = 0.0
	_forward_m = 0.0


func update(offset_m: float, now_s: float) -> void:
	if lap_length_m <= 0.0:
		return
	if not started:
		start(offset_m, now_s)
		return

	_now_s = now_s
	var step := _signed_step(offset_m)
	_previous_offset_m = offset_m
	_progress_m += step
	_update_direction(step)
	_settle_sectors(now_s)


func current_lap_s() -> float:
	return 0.0 if not started else _now_s - _lap_start_s


func progress_m() -> float:
	return _progress_m


func lap_fraction() -> float:
	if lap_length_m <= 0.0:
		return 0.0
	return fposmod(_progress_m, lap_length_m) / lap_length_m


func _sector_length_m() -> float:
	return lap_length_m / float(sector_count)


func _signed_step(offset_m: float) -> float:
	var step := offset_m - _previous_offset_m
	var half := lap_length_m * 0.5
	if step > half:
		return step - lap_length_m
	if step < -half:
		return step + lap_length_m
	return step


func _update_direction(step: float) -> void:
	if step < 0.0:
		_backward_m -= step
		_forward_m = 0.0
	elif step > 0.0:
		_forward_m += step
		if _forward_m >= RECOVERY_DISTANCE_M:
			_backward_m = 0.0

	var active := _backward_m >= WRONG_WAY_DISTANCE_M
	if active == wrong_way:
		return
	wrong_way = active
	if active:
		lap_valid = false
	wrong_way_changed.emit(active)


func _settle_sectors(now_s: float) -> void:
	var reached := int(floor(_progress_m / _sector_length_m()))
	while _sectors_passed > reached:
		_sectors_passed -= 1
		_sector_start_s = now_s
		_lap_start_s = now_s
		lap_valid = false
		laps_completed = maxi(_sectors_passed, 0) / sector_count

	while _sectors_passed < reached:
		_sectors_passed += 1
		var index := posmod(_sectors_passed - 1, sector_count)
		var split := now_s - _sector_start_s
		_sector_start_s = now_s
		if lap_valid:
			last_sector_s[index] = split
			sector_completed.emit(index, split)
		if _sectors_passed % sector_count == 0:
			_complete_lap(now_s)

	sector = posmod(_sectors_passed, sector_count)


func _complete_lap(now_s: float) -> void:
	laps_completed = maxi(_sectors_passed, 0) / sector_count
	var seconds := now_s - _lap_start_s
	_lap_start_s = now_s
	if not lap_valid:
		lap_valid = true
		return
	last_lap_s = seconds
	if best_lap_s <= 0.0 or last_lap_s < best_lap_s:
		best_lap_s = last_lap_s
	lap_completed.emit(laps_completed, last_lap_s)
