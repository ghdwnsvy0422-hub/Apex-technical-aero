class_name ChaseCamera
extends Camera3D
## Follows the car from behind, from further back, or from the cockpit.

enum Mode { CHASE, FAR, COCKPIT }

const _OFFSETS: Dictionary = {
	Mode.CHASE: Vector3(0.0, 1.75, 6.6),
	Mode.FAR: Vector3(0.0, 3.10, 10.5),
	Mode.COCKPIT: Vector3(0.0, 1.05, -0.15),
}

const FOLLOW_RATE: float = 9.0
const AIM_DISTANCE: float = 14.0
const BASE_FOV: float = 72.0
const MAX_FOV: float = 94.0
## Speed at which the field of view has fully widened, in m/s.
const FOV_REFERENCE: float = 90.0

var target: CarBody
var mode: Mode = Mode.CHASE

var _looking_back: bool = false


func _process(delta: float) -> void:
	if target == null:
		return

	if Input.is_action_just_pressed("camera_cycle"):
		mode = ((mode + 1) % Mode.size()) as Mode
	_looking_back = Input.is_action_pressed("look_back")

	var heading := _stable_heading()
	var offset: Vector3 = _OFFSETS[mode]
	if _looking_back:
		offset.z = -offset.z

	var anchor := target.global_position
	var desired := anchor + heading * offset

	if mode == Mode.COCKPIT:
		global_position = desired
	else:
		# Exponential smoothing rather than a fixed lerp factor, so the camera
		# settles at the same rate whatever the frame rate.
		global_position = global_position.lerp(
			desired, 1.0 - exp(-FOLLOW_RATE * delta)
		)

	var aim_direction := -heading.z * (-1.0 if _looking_back else 1.0)
	look_at(anchor + aim_direction * AIM_DISTANCE + Vector3.UP * 0.9, Vector3.UP)

	fov = lerpf(
		BASE_FOV, MAX_FOV,
		clampf(target.linear_velocity.length() / FOV_REFERENCE, 0.0, 1.0)
	)


## The car's own basis rolls and pitches over kerbs. Following that directly is
## unpleasant to look at, so only its heading is used.
func _stable_heading() -> Basis:
	var forward := target.global_transform.basis * Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Basis.IDENTITY
	return Basis.looking_at(forward.normalized(), Vector3.UP)
