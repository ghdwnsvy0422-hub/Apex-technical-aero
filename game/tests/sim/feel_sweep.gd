extends Node3D

const TAG: String = "FeelSweep"

const COM_HEIGHTS: Array[float] = [0.22, 0.28, 0.34]
const AERO_BALANCES: Array[float] = [0.38, 0.45, 0.52]
const STEER_FACTORS: Array[float] = [0.16, 0.22, 0.30]

var _rows: Array[Dictionary] = []


func _ready() -> void:
	await _sweep_axis("com height", COM_HEIGHTS, _setup_with_com_height)
	await _sweep_axis("aero balance", AERO_BALANCES, _setup_with_aero_balance)
	await _sweep_axis("steer factor", STEER_FACTORS, _setup_with_steer_factor)
	_print_table()
	get_tree().quit(0)


func _sweep_axis(axis: String, values: Array[float], build: Callable) -> void:
	for value: float in values:
		var setup: CarSetup = build.call(value)
		var metrics: HandlingMetrics = await HandlingMetrics.measure(self, setup)
		Log.info(TAG, "%s %.2f: %s" % [axis, value, metrics.describe()])
		_rows.append({
			"axis": axis,
			"value": value,
			"metrics": metrics,
			"baseline": is_equal_approx(value, _baseline_for(axis)),
		})


func _baseline_for(axis: String) -> float:
	var reference := CarSetup.new()
	match axis:
		"com height":
			return reference.com_height_above_ground
		"aero balance":
			return reference.aero_balance
		"steer factor":
			return reference.high_speed_steer_factor
	return NAN


func _setup_with_com_height(value: float) -> CarSetup:
	var setup := CarSetup.new()
	setup.com_height_above_ground = value
	return setup


func _setup_with_aero_balance(value: float) -> CarSetup:
	var setup := CarSetup.new()
	setup.aero_balance = value
	return setup


func _setup_with_steer_factor(value: float) -> CarSetup:
	var setup := CarSetup.new()
	setup.high_speed_steer_factor = value
	return setup


func _print_table() -> void:
	Log.info(TAG, "")
	Log.info(TAG, "  axis          value   response  overshoot    balance  label       rotation  power gain  power slip  headroom  brake slip")
	for row: Dictionary in _rows:
		var metrics: HandlingMetrics = row["metrics"]
		Log.info(TAG, "  %-12s  %5.2f  %6.3f s  %9.2f  %+6.2f deg  %-10s  %8.2f  %10.2f  %6.1f deg  %6.0f%%  %7.2f deg%s" % [
			row["axis"],
			row["value"],
			metrics.steer_response_s,
			metrics.yaw_overshoot,
			metrics.slip_balance_deg,
			HandlingMetrics.balance_label(metrics.slip_balance_deg),
			metrics.corner_rotation_ratio,
			metrics.power_rotation_gain,
			metrics.power_body_slip_deg,
			metrics.throttle_headroom * 100.0,
			metrics.brake_body_slip_deg,
			"  <- shipped" if row["baseline"] else "",
		])
	Log.info(TAG, "")
	Log.info(TAG, "balance: positive is understeer, negative is oversteer.")
	Log.info(TAG, "rotation: 1.0 follows the steering geometry, below is understeer, above is oversteer.")
	Log.info(TAG, "See docs/DRIVING_FEEL.md.")
