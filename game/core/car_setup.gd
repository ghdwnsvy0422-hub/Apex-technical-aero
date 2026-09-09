class_name CarSetup
extends RefCounted
## Physical parameters of one car, in SI units.
##
## Phase 3.2 will derive these from fitted parts and setup sliders. Until then
## the defaults describe a single open-wheel reference car, chosen so the
## resulting behaviour lands in a plausible range (roughly 340 km/h top speed,
## ~2 tonnes of downforce at speed) rather than being tuned for feel.

# --- chassis ---
var mass: float = 800.0
var wheelbase: float = 3.60
var track_width: float = 1.60
## Measured from the ground, not from the chassis origin, because it is the
## ground-relative height that governs weight transfer. Low values make the car
## resist transfer; this is the main lever on how twitchy it feels.
var com_height_above_ground: float = 0.28
var body_size: Vector3 = Vector3(1.0, 0.50, 4.80)

# --- wheels ---
var wheel_radius: float = 0.36
var wheel_mass: float = 12.0
## Rotating inertia of the engine and gearbox internals. Small on its own, but
## it reaches the wheels multiplied by the square of the gear ratio, where in
## first gear it dwarfs the wheels themselves.
var engine_inertia: float = 0.10
## Fraction of the car's weight carried by the front axle. Below 0.5 puts more
## load on the driven rear wheels, which is where an open-wheel car sits.
var front_weight_bias: float = 0.46

# --- suspension ---
var suspension_rest_length: float = 0.12
var suspension_travel: float = 0.10
## Stiff enough that peak downforce does not use up the whole travel: at
## ~2 tonnes of load the car must still be riding on springs, not bump stops.
var suspension_stiffness: float = 130000.0
var suspension_damping_compression: float = 5500.0
var suspension_damping_rebound: float = 7500.0

# --- tyres ---
var tyre_friction: float = 1.70
## Scales grip with load sub-linearly, which is what makes weight transfer cost
## total grip and why smooth driving is faster.
var load_sensitivity: float = 0.85
var rolling_resistance: float = 0.014

# --- powertrain ---
var engine_idle_rpm: float = 3500.0
var engine_max_rpm: float = 13000.0
var engine_peak_torque_rpm: float = 10500.0
var engine_peak_torque: float = 480.0
var gear_ratios: Array[float] = [3.90, 3.10, 2.60, 2.25, 1.98, 1.76, 1.58, 1.41]
var final_drive: float = 3.40
var drivetrain_efficiency: float = 0.95
var shift_up_rpm: float = 12400.0
var shift_down_rpm: float = 8200.0
var shift_duration: float = 0.06
## Minimum time between shifts. A gearbox that may shift on any tick will
## oscillate between two gears the moment the engine hovers near a threshold.
var shift_cooldown: float = 0.30

# --- brakes ---
var max_brake_torque: float = 9000.0
## Share of brake torque sent to the front axle (PRD 22 brake balance).
var brake_balance: float = 0.58

# --- aero ---
## Drag area of the bare car, Cd * A, before any wing is fitted.
var drag_area: float = 0.70
## Downforce area, Cl * A (PRD 27: raising this trades top speed for cornering).
var downforce_area: float = 4.00
## Drag added per unit of downforce area. Without this the two are independent
## and wings become free grip, which collapses every track to one setup.
var induced_drag_factor: float = 0.16
var air_density: float = 1.225
var aero_balance: float = 0.45

# --- steering ---
var max_steer_angle: float = 0.36
## Steering is reduced towards this fraction of full lock at high speed,
## otherwise a full-lock input at 300 km/h would simply spin the car.
var high_speed_steer_factor: float = 0.22
var steer_speed_reference: float = 75.0


func corner_mass() -> float:
	return mass * 0.25


## A tyre carries most of its mass out at the tread rather than spread through
## a disc, so its inertia sits close to the hoop value.
func wheel_inertia() -> float:
	return 0.9 * wheel_mass * wheel_radius * wheel_radius


## Inertia a driven wheel actually has to accelerate, including the engine and
## gearbox seen through the gearing and shared across the driven wheels.
func driven_wheel_inertia(total_gear_ratio: float, driven_count: int) -> float:
	if driven_count <= 0:
		return wheel_inertia()
	return wheel_inertia() + engine_inertia * total_gear_ratio * total_gear_ratio / driven_count


## The chassis origin sits at the suspension mounts, so the contact plane is a
## full uncompressed ray length below it.
func contact_depth() -> float:
	return suspension_rest_length + wheel_radius


func center_of_mass_offset() -> Vector3:
	return Vector3(0.0, com_height_above_ground - contact_depth(), 0.0)


## The axle carrying less weight sits further from the centre of mass, so a
## front bias below 0.5 places the front axle further forward.
func front_axle_z() -> float:
	return wheelbase * (1.0 - front_weight_bias)


func rear_axle_z() -> float:
	return -wheelbase * front_weight_bias


## Suspension rest position measured from the chassis origin, per wheel.
func wheel_offsets() -> Array[Vector3]:
	var half_track := track_width * 0.5
	return [
		Vector3(-half_track, 0.0, front_axle_z()),
		Vector3(half_track, 0.0, front_axle_z()),
		Vector3(-half_track, 0.0, rear_axle_z()),
		Vector3(half_track, 0.0, rear_axle_z()),
	]
