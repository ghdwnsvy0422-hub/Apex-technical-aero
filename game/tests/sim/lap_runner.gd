class_name LapRunner
extends RefCounted

const TICK_RATE: int = 120
const SETTLE_TICKS: int = TICK_RATE
const RIDE_HEIGHT_MARGIN_M: float = 0.10

var laps_completed: int = 0
var best_lap_s: float = 0.0
var lap_times_s: PackedFloat32Array = PackedFloat32Array()
var widest_lateral_m: float = 0.0
var slowest_kph: float = INF
var wrong_way: bool = false
var elapsed_s: float = 0.0

var _host: Node
var _track: Track
var _timer: LapTimer
var _driver: AiDriver
var _car: CarBody


static func run(
	host: Node,
	track: Track,
	line: RacingLine,
	setup: CarSetup,
	sector_count: int,
	target_laps: int,
	timeout_s: int
) -> LapRunner:
	var runner := LapRunner.new()
	runner._host = host
	runner._track = track
	runner._timer = LapTimer.create(track.length(), sector_count)
	runner._driver = AiDriver.create(line, track.curve)
	await runner._drive(setup, target_laps, timeout_s)
	return runner


func finished(target_laps: int) -> bool:
	return laps_completed >= target_laps


func _drive(setup: CarSetup, target_laps: int, timeout_s: int) -> void:
	_car = CarBody.new()
	if setup != null:
		_car.setup = setup
	_car.transform = _track.start_transform(_car.setup.contact_depth() + RIDE_HEIGHT_MARGIN_M)
	_host.add_child(_car)

	_car.input = DriverInput.new()
	for _tick: int in SETTLE_TICKS:
		await _host.get_tree().physics_frame

	_timer.start(_driver.centreline_offset(_car.global_position), 0.0)
	_timer.lap_completed.connect(_on_lap_completed)

	var ticks := 0
	var limit := timeout_s * TICK_RATE
	while _timer.laps_completed < target_laps and ticks < limit:
		_car.input = _driver.input_for(_car.global_transform, _car.linear_velocity)
		await _host.get_tree().physics_frame
		ticks += 1
		_observe(float(ticks) / TICK_RATE)

	elapsed_s = float(ticks) / TICK_RATE
	laps_completed = _timer.laps_completed
	best_lap_s = _timer.best_lap_s
	wrong_way = _timer.wrong_way

	_host.remove_child(_car)
	_car.queue_free()


func _observe(now_s: float) -> void:
	_timer.update(_driver.centreline_offset(_car.global_position), now_s)
	if _timer.laps_completed < 1:
		return

	var here := _car.global_position
	var nearest := _track.curve.get_closest_point(here)
	widest_lateral_m = maxf(widest_lateral_m, Vector2(here.x - nearest.x, here.z - nearest.z).length())
	slowest_kph = minf(slowest_kph, _car.speed_kph())


func _on_lap_completed(_lap: int, seconds: float) -> void:
	lap_times_s.append(seconds)
