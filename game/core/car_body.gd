class_name CarBody
extends RigidBody3D
## Raycast-suspension race car.
##
## Deliberately not a VehicleBody3D (CLAUDE.md rule 2): tyre wear, downforce
## trade-offs and per-corner damage all need access to per-wheel load and slip,
## which the built-in node does not expose.
##
## Runs identically headless, so the dedicated server and the AI driver harness
## execute this same code. Driver intent arrives as a value through `input`.

signal gear_changed(new_gear: int)

var setup: CarSetup = CarSetup.new()
var input: DriverInput = DriverInput.new()
var wheels: Array[Wheel] = []

var gear: int = 0
var engine_rpm: float = 0.0

var _shift_timer: float = 0.0
var _shift_cooldown: float = 0.0


func _ready() -> void:
	_configure_body()
	_build_wheels()


func _physics_process(delta: float) -> void:
	_shift_timer = maxf(_shift_timer - delta, 0.0)
	_shift_cooldown = maxf(_shift_cooldown - delta, 0.0)

	_update_steering()
	var drive_torque := _update_powertrain()
	var space := get_world_3d().direct_space_state
	for wheel: Wheel in wheels:
		_simulate_wheel(wheel, space, drive_torque, delta)
	_apply_aero()


func speed_kph() -> float:
	return linear_velocity.length() * 3.6


## Forward speed along the car's own axis, which unlike `speed_kph` goes
## negative when the car is travelling backwards.
func forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis * Vector3.FORWARD)


func grounded_wheel_count() -> int:
	var count := 0
	for wheel: Wheel in wheels:
		if wheel.grounded:
			count += 1
	return count


func teleport_to(target: Transform3D) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = target
	gear = 0
	engine_rpm = setup.engine_idle_rpm
	_shift_timer = 0.0
	_shift_cooldown = 0.0
	for wheel: Wheel in wheels:
		wheel.reset()


func _configure_body() -> void:
	mass = setup.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = setup.center_of_mass_offset()
	# A race car is never idle long enough to be worth sleeping, and a sleeping
	# body would stop reporting state to the server.
	can_sleep = false
	continuous_cd = true

	# Godot's default damping is a velocity-proportional force that at racing
	# speeds outweighs real drag - it silently ate ~5 kN at 220 km/h and capped
	# the car there. Aero is this model's job, so engine damping is replaced
	# outright rather than merely zeroed, which would still combine with any
	# world or area default.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	if get_node_or_null("Collision") == null:
		_build_collision()


func _build_collision() -> void:
	var box := BoxShape3D.new()
	box.size = setup.body_size
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	shape.shape = box
	# Sit the floor of the chassis just above the contact plane so the body
	# does not ground out before the suspension has used its travel.
	shape.position = Vector3(
		0.0, setup.body_size.y * 0.5 + 0.10 - setup.contact_depth(), 0.0
	)
	add_child(shape)


func _build_wheels() -> void:
	wheels.clear()
	var offsets := setup.wheel_offsets()
	for index: int in offsets.size():
		var is_front := index < 2
		wheels.append(Wheel.create(offsets[index], is_front, not is_front))


## Steering authority falls away with speed. At full lock and 300 km/h the
## front tyres would simply be asked for more grip than they have, so the car
## would spin rather than turn.
func _update_steering() -> void:
	var blend := clampf(linear_velocity.length() / setup.steer_speed_reference, 0.0, 1.0)
	var authority := lerpf(1.0, setup.high_speed_steer_factor, blend)
	var angle := input.steer * setup.max_steer_angle * authority
	for wheel: Wheel in wheels:
		if wheel.is_front:
			wheel.steer_angle = angle


## Returns drive torque for one driven wheel.
func _update_powertrain() -> float:
	var ratio := Powertrain.total_ratio(gear, setup)

	# Engine speed follows the driven wheels, so wheelspin revs the engine into
	# the limiter and torque is cut - the spin limits itself.
	engine_rpm = Powertrain.engine_rpm(
		_driven_angular_velocity(), ratio, setup.engine_idle_rpm
	)

	# Gears follow whichever is lower, engine or road speed. Engine speed alone
	# short-shifts to top gear during wheelspin; road speed alone ignores the
	# limiter. The lower of the two upshifts only once the car is genuinely
	# travelling that fast, and still downshifts as it slows.
	var road_rpm := Powertrain.engine_rpm(
		absf(forward_speed()) / setup.wheel_radius, ratio, setup.engine_idle_rpm
	)

	if _shift_timer <= 0.0 and _shift_cooldown <= 0.0:
		var next_gear := Powertrain.select_gear(gear, minf(engine_rpm, road_rpm), setup)
		if next_gear != gear:
			gear = next_gear
			_shift_timer = setup.shift_duration
			_shift_cooldown = setup.shift_cooldown
			gear_changed.emit(gear)

	# Torque is cut through the shift, which is what makes gearing choices
	# cost time rather than being free.
	var throttle := 0.0 if _shift_timer > 0.0 else input.throttle
	return Powertrain.axle_torque(engine_rpm, throttle, gear, setup) * 0.5


## Driven wheels must also accelerate the engine and gearbox through the
## gearing, which in first gear is an order of magnitude more inertia than the
## wheel itself. Without it the tyres light up within a single tick and the
## car never finds traction again.
func _spin_inertia(wheel: Wheel) -> float:
	if not wheel.is_driven:
		return setup.wheel_inertia()
	return setup.driven_wheel_inertia(Powertrain.total_ratio(gear, setup), _driven_wheel_count())


func _driven_wheel_count() -> int:
	var count := 0
	for wheel: Wheel in wheels:
		if wheel.is_driven:
			count += 1
	return count


func _driven_angular_velocity() -> float:
	var total := 0.0
	var count := 0
	for wheel: Wheel in wheels:
		if wheel.is_driven:
			total += wheel.angular_velocity
			count += 1
	return total / count if count > 0 else 0.0


func _simulate_wheel(
	wheel: Wheel, space: PhysicsDirectSpaceState3D, drive_torque: float, delta: float
) -> void:
	var up := global_transform.basis.y
	var mount := global_transform * wheel.offset
	var ray_length := setup.suspension_rest_length + setup.wheel_radius

	var query := PhysicsRayQueryParameters3D.create(mount, mount - up * ray_length)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)

	var braking := Powertrain.brake_torque(input.brake, wheel.is_front, setup)
	var inertia := _spin_inertia(wheel)

	if hit.is_empty():
		wheel.grounded = false
		wheel.compression = 0.0
		wheel.load = 0.0
		wheel.longitudinal_force = 0.0
		wheel.lateral_force = 0.0
		var airborne_drive := drive_torque if wheel.is_driven else 0.0
		wheel.integrate_spin(airborne_drive, braking, 0.0, inertia, setup, delta)
		return

	wheel.grounded = true
	wheel.contact_point = hit["position"]
	wheel.surface_friction = _surface_friction(hit)

	var suspension_length := mount.distance_to(wheel.contact_point) - setup.wheel_radius
	wheel.compression = clampf(
		setup.suspension_rest_length - suspension_length, 0.0, setup.suspension_travel
	)

	var contact_velocity := _velocity_at(wheel.contact_point)
	var load := Wheel.suspension_force(wheel.compression, contact_velocity.dot(up), setup)
	wheel.load = load
	apply_force(up * load, wheel.contact_point - global_position)

	var normal: Vector3 = hit["normal"]
	var forward := (global_transform.basis * Vector3.FORWARD).rotated(up, -wheel.steer_angle)
	var right := forward.cross(up)
	var ground_forward := (forward - normal * forward.dot(normal)).normalized()
	var ground_right := (right - normal * right.dot(normal)).normalized()

	var longitudinal_speed := contact_velocity.dot(ground_forward)
	var lateral_speed := contact_velocity.dot(ground_right)

	wheel.slip_ratio = TyreModel.slip_ratio(
		wheel.surface_speed(setup.wheel_radius), longitudinal_speed
	)
	wheel.slip_angle = TyreModel.slip_angle(lateral_speed, longitudinal_speed)

	var coefficients := TyreModel.combined_coefficients(wheel.slip_ratio, wheel.slip_angle)
	var limit := TyreModel.grip_limit(
		load, setup.tyre_friction * wheel.surface_friction, setup.load_sensitivity
	)
	wheel.longitudinal_force = coefficients.x * limit
	wheel.lateral_force = coefficients.y * limit

	apply_force(
		ground_forward * wheel.longitudinal_force + ground_right * wheel.lateral_force,
		wheel.contact_point - global_position
	)

	var rolling := setup.rolling_resistance * load * setup.wheel_radius
	var wheel_drive := drive_torque if wheel.is_driven else 0.0
	wheel.integrate_spin(
		wheel_drive, braking + rolling, wheel.longitudinal_force, inertia, setup, delta
	)


func _apply_aero() -> void:
	var speed := linear_velocity.length()
	if speed < 0.5:
		return

	apply_central_force(-linear_velocity.normalized() * Aero.drag(speed, setup))

	# Split downforce across the axles so aero balance shifts the car's
	# behaviour the way wing settings should (PRD 22).
	var down := -global_transform.basis.y * Aero.downforce(speed, setup)
	var front_point := global_transform * Vector3(0.0, 0.0, setup.front_axle_z())
	var rear_point := global_transform * Vector3(0.0, 0.0, setup.rear_axle_z())
	apply_force(down * setup.aero_balance, front_point - global_position)
	apply_force(down * (1.0 - setup.aero_balance), rear_point - global_position)


## Surfaces advertise their own grip through metadata, so running wide onto
## the runoff costs time without the physics knowing what a track is.
func _surface_friction(hit: Dictionary) -> float:
	var collider: Object = hit.get("collider")
	if collider == null or not collider.has_meta(&"surface_friction"):
		return 1.0
	return float(collider.get_meta(&"surface_friction"))


func _velocity_at(point: Vector3) -> Vector3:
	var com := global_transform * center_of_mass
	return linear_velocity + angular_velocity.cross(point - com)
