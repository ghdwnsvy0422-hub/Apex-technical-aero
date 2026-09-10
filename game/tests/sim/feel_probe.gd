extends Node3D

const TAG: String = "FeelProbe"

const MAX_RESPONSE_S: float = 0.80
const MIN_RESPONSE_S: float = 0.02
const MAX_OVERSHOOT: float = 2.50
const MAX_BALANCE_DEG: float = 6.00
const MIN_BALANCE_DEG: float = -4.00
const MIN_THROTTLE_HEADROOM: float = 0.40
const MAX_EXIT_BODY_SLIP_DEG: float = 10.00
const MAX_BRAKE_BODY_SLIP_DEG: float = 12.00
const AERO_BALANCE_MARGIN: float = 0.01

var _failures: PackedStringArray = []


func _ready() -> void:
	var metrics: HandlingMetrics = await HandlingMetrics.measure(self, CarSetup.new())
	Log.info(TAG, metrics.describe())
	_report_metrics(metrics)
	await _report_aero_balance_margin()
	_report()


func _report_aero_balance_margin() -> void:
	var nudged := CarSetup.new()
	nudged.aero_balance += AERO_BALANCE_MARGIN
	var slip: float = await HandlingMetrics.measure_corner_exit(self, nudged)
	Log.info(TAG, "aero balance %.3f corner exit: %.1f deg" % [nudged.aero_balance, slip])
	_check(
		slip <= MAX_EXIT_BODY_SLIP_DEG,
		"aero balance keeps %.3f of margin before a normal exit spins (%.1f deg at %.3f)" % [
			AERO_BALANCE_MARGIN, slip, nudged.aero_balance
		]
	)


func _report_metrics(metrics: HandlingMetrics) -> void:
	_check(
		metrics.steer_response_s >= MIN_RESPONSE_S
		and metrics.steer_response_s <= MAX_RESPONSE_S,
		"the car answers the wheel in %.2f-%.2f s (got %.3f s)" % [
			MIN_RESPONSE_S, MAX_RESPONSE_S, metrics.steer_response_s
		]
	)
	_check(
		metrics.yaw_overshoot <= MAX_OVERSHOOT,
		"yaw settles instead of snapping past (overshoot %.2f, limit %.2f)" % [
			metrics.yaw_overshoot, MAX_OVERSHOOT
		]
	)
	_check(
		metrics.slip_balance_deg >= MIN_BALANCE_DEG
		and metrics.slip_balance_deg <= MAX_BALANCE_DEG,
		"axle balance stays inside %+.1f..%+.1f deg (got %+.2f, %s)" % [
			MIN_BALANCE_DEG, MAX_BALANCE_DEG, metrics.slip_balance_deg,
			HandlingMetrics.balance_label(metrics.slip_balance_deg)
		]
	)
	_check(
		metrics.throttle_headroom >= MIN_THROTTLE_HEADROOM,
		"the driver has throttle to spend at the cornering limit (%.0f%% usable, need %.0f%%)" % [
			metrics.throttle_headroom * 100.0, MIN_THROTTLE_HEADROOM * 100.0
		]
	)
	_check(
		metrics.exit_body_slip_deg <= MAX_EXIT_BODY_SLIP_DEG,
		"unwinding the wheel onto full throttle stays clean (%.1f deg, limit %.1f)" % [
			metrics.exit_body_slip_deg, MAX_EXIT_BODY_SLIP_DEG
		]
	)
	_check(
		metrics.brake_body_slip_deg <= MAX_BRAKE_BODY_SLIP_DEG,
		"the car stays pointed along its travel under braking (%.1f deg, limit %.1f)" % [
			metrics.brake_body_slip_deg, MAX_BRAKE_BODY_SLIP_DEG
		]
	)


func _report() -> void:
	if _failures.is_empty():
		Log.info(TAG, "All feel probes passed")
		get_tree().quit(0)
		return
	Log.error(TAG, "%d feel probe(s) failed" % _failures.size())
	get_tree().quit(1)


func _check(passed: bool, description: String) -> void:
	if passed:
		Log.info(TAG, "PASS  %s" % description)
		return
	_failures.append(description)
	Log.error(TAG, "FAIL  %s" % description)
