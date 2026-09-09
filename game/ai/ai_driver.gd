class_name AiDriver
extends RefCounted

const LOOKAHEAD_SECONDS: float = 0.62
const MIN_LOOKAHEAD_M: float = 14.0
const MAX_LOOKAHEAD_M: float = 75.0
const STEER_GAIN: float = 2.6

const SPEED_PREVIEW_SECONDS: float = 0.45
const SPEED_DEADBAND_MPS: float = 0.6
const THROTTLE_GAIN: float = 0.30
const BRAKE_GAIN: float = 0.22

const TRACTION_FLOOR_THROTTLE: float = 0.28
const TRACTION_RAMP_MPS: float = 16.0

var line: RacingLine
var curve: Curve3D


static func create(racing_line: RacingLine, track_curve: Curve3D) -> AiDriver:
	var driver := AiDriver.new()
	driver.line = racing_line
	driver.curve = track_curve
	return driver


func is_ready() -> bool:
	return curve != null and line != null and not line.points.is_empty()


func centreline_offset(position: Vector3) -> float:
	if curve == null:
		return 0.0
	return curve.get_closest_offset(position)


func input_for(car_transform: Transform3D, velocity: Vector3) -> DriverInput:
	if not is_ready():
		return DriverInput.new()

	var speed := velocity.length()
	var offset := centreline_offset(car_transform.origin)
	var target_speed := line.speed_for_offset(offset + speed * SPEED_PREVIEW_SECONDS)

	return DriverInput.create(
		throttle_for(speed, target_speed),
		brake_for(speed, target_speed),
		steer_towards_line(car_transform, offset, speed)
	)


func steer_towards_line(car_transform: Transform3D, offset: float, speed: float) -> float:
	var target := line.point_for_offset(offset + lookahead_for(speed))
	return steer_towards_point(car_transform, target)


func lookahead_for(speed: float) -> float:
	return clampf(speed * LOOKAHEAD_SECONDS, MIN_LOOKAHEAD_M, MAX_LOOKAHEAD_M)


static func steer_towards_point(car_transform: Transform3D, target: Vector3) -> float:
	var to_target := target - car_transform.origin
	to_target.y = 0.0
	if to_target.length_squared() < 1.0:
		return 0.0

	var forward := car_transform.basis * Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	if right.length_squared() < 0.000001:
		return 0.0

	return clampf(to_target.normalized().dot(right.normalized()) * STEER_GAIN, -1.0, 1.0)


static func throttle_for(speed: float, target_speed: float) -> float:
	if speed > target_speed - SPEED_DEADBAND_MPS:
		return 0.0
	return clampf((target_speed - speed) * THROTTLE_GAIN, 0.0, traction_limit(speed))


static func brake_for(speed: float, target_speed: float) -> float:
	if speed < target_speed + SPEED_DEADBAND_MPS:
		return 0.0
	return clampf((speed - target_speed) * BRAKE_GAIN, 0.0, 1.0)


static func traction_limit(speed: float) -> float:
	return clampf(TRACTION_FLOOR_THROTTLE + speed / TRACTION_RAMP_MPS, 0.0, 1.0)
