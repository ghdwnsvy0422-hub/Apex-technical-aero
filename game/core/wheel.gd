class_name Wheel
extends RefCounted
## State of one wheel: suspension travel, load, spin, and the slip it is
## currently generating.
##
## Wheel rotation is simulated rather than inferred from car speed, because
## wheelspin and lockup are what make throttle and brake inputs feel like
## decisions. They also drive tyre wear later (PRD 29, 30).

var offset: Vector3 = Vector3.ZERO
var is_front: bool = false
var is_driven: bool = false

var steer_angle: float = 0.0
var angular_velocity: float = 0.0
## Metres of suspension compression, 0 at full droop.
var compression: float = 0.0
## Vertical load through the contact patch, in newtons.
var load: float = 0.0
var grounded: bool = false
var contact_point: Vector3 = Vector3.ZERO
var slip_ratio: float = 0.0
var slip_angle: float = 0.0
var longitudinal_force: float = 0.0
var lateral_force: float = 0.0


static func create(mount_offset: Vector3, front: bool, driven: bool) -> Wheel:
	var wheel := Wheel.new()
	wheel.offset = mount_offset
	wheel.is_front = front
	wheel.is_driven = driven
	return wheel


## Spring plus damper along the suspension axis. Never negative: a strut can
## push the chassis up but cannot pull it down onto the road.
static func suspension_force(
	compression_distance: float, axis_velocity: float, setup: CarSetup
) -> float:
	var spring := setup.suspension_stiffness * compression_distance
	var damping := (
		setup.suspension_damping_compression if axis_velocity < 0.0
		else setup.suspension_damping_rebound
	)
	return maxf(spring - damping * axis_velocity, 0.0)


func surface_speed(wheel_radius: float) -> float:
	return angular_velocity * wheel_radius


## Advances wheel rotation for one tick. `tyre_force` is the longitudinal force
## the contact patch is already producing, whose reaction is what slows a
## spinning wheel back down to road speed.
func integrate_spin(
	drive_torque: float, braking_torque: float, tyre_force: float,
	inertia: float, setup: CarSetup, delta: float
) -> void:
	if inertia <= 0.0:
		return

	var reaction := -tyre_force * setup.wheel_radius
	angular_velocity += (drive_torque + reaction) / inertia * delta

	# Brakes may bring a wheel to rest but must never drive it backwards,
	# which is what an unclamped torque would do in a single large step.
	var brake_delta := braking_torque / inertia * delta
	if absf(angular_velocity) <= brake_delta:
		angular_velocity = 0.0
	else:
		angular_velocity -= signf(angular_velocity) * brake_delta


func reset() -> void:
	steer_angle = 0.0
	angular_velocity = 0.0
	compression = 0.0
	load = 0.0
	grounded = false
	slip_ratio = 0.0
	slip_angle = 0.0
	longitudinal_force = 0.0
	lateral_force = 0.0
