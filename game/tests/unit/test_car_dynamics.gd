extends GutTest
## Aerodynamics, suspension and wheel rotation.

var _setup: CarSetup


func before_each() -> void:
	_setup = CarSetup.new()


# --- aero ------------------------------------------------------------------

func test_aero_forces_scale_with_the_square_of_speed() -> void:
	assert_almost_eq(Aero.drag(100.0, _setup), Aero.drag(50.0, _setup) * 4.0, 0.01)
	assert_almost_eq(Aero.downforce(100.0, _setup), Aero.downforce(50.0, _setup) * 4.0, 0.01)


func test_no_aero_force_at_a_standstill() -> void:
	assert_eq(Aero.drag(0.0, _setup), 0.0)
	assert_eq(Aero.downforce(0.0, _setup), 0.0)


func test_wings_bring_their_own_drag() -> void:
	# PRD 27. Without this coupling downforce is free grip and every track
	# collapses to a single optimal setup.
	var low := CarSetup.new()
	low.downforce_area = 1.5
	var high := CarSetup.new()
	high.downforce_area = 6.0
	assert_gt(Aero.drag(80.0, high), Aero.drag(80.0, low))


# --- suspension ------------------------------------------------------------

func test_suspension_pushes_back_when_compressed() -> void:
	assert_gt(Wheel.suspension_force(0.05, 0.0, _setup), 0.0)


func test_suspension_never_pulls_the_chassis_down() -> void:
	# A strut at full droop with the chassis rising fast would otherwise
	# produce a negative force and hold the car onto the road.
	assert_eq(Wheel.suspension_force(0.0, 20.0, _setup), 0.0)


func test_damper_resists_compression() -> void:
	var still: float = Wheel.suspension_force(0.05, 0.0, _setup)
	var compressing: float = Wheel.suspension_force(0.05, -1.0, _setup)
	assert_gt(compressing, still)


func test_static_ride_height_leaves_travel_in_hand() -> void:
	# If the car sat on its bump stops at rest, downforce would have nowhere
	# to go and the chassis would ground out at speed.
	var sag := _setup.mass * 9.8 / (4.0 * _setup.suspension_stiffness)
	assert_lt(sag, _setup.suspension_travel * 0.5)


# --- wheel rotation --------------------------------------------------------

func test_drive_torque_spins_the_wheel_up() -> void:
	var wheel := Wheel.create(Vector3.ZERO, false, true)
	wheel.integrate_spin(500.0, 0.0, 0.0, 2.0, _setup, 0.01)
	assert_gt(wheel.angular_velocity, 0.0)


func test_tyre_reaction_slows_a_spinning_wheel() -> void:
	var wheel := Wheel.create(Vector3.ZERO, false, true)
	wheel.angular_velocity = 100.0
	wheel.integrate_spin(0.0, 0.0, 3000.0, 2.0, _setup, 0.01)
	assert_lt(wheel.angular_velocity, 100.0)


func test_brakes_stop_a_wheel_without_reversing_it() -> void:
	# A single large step of unclamped brake torque would spin the wheel
	# backwards, which reads as the car suddenly gripping in reverse.
	var wheel := Wheel.create(Vector3.ZERO, true, false)
	wheel.angular_velocity = 5.0
	wheel.integrate_spin(0.0, 100000.0, 0.0, 2.0, _setup, 0.1)
	assert_eq(wheel.angular_velocity, 0.0)


func test_zero_inertia_wheel_is_left_alone() -> void:
	var wheel := Wheel.create(Vector3.ZERO, false, true)
	wheel.integrate_spin(500.0, 0.0, 0.0, 0.0, _setup, 0.01)
	assert_eq(wheel.angular_velocity, 0.0)


# --- geometry --------------------------------------------------------------

func test_gearing_dominates_driven_wheel_inertia_in_first() -> void:
	# Omitting reflected engine inertia lights the tyres up inside one tick.
	var first := Powertrain.total_ratio(0, _setup)
	assert_gt(
		_setup.driven_wheel_inertia(first, 2),
		_setup.wheel_inertia() * 4.0
	)


func test_rear_bias_puts_the_front_axle_further_from_the_centre_of_mass() -> void:
	_setup.front_weight_bias = 0.46
	assert_gt(absf(_setup.front_axle_z()), absf(_setup.rear_axle_z()))


func test_axle_positions_span_the_wheelbase() -> void:
	assert_almost_eq(_setup.rear_axle_z() - _setup.front_axle_z(), _setup.wheelbase, 0.001)


func test_front_axle_is_ahead_of_the_rear() -> void:
	# Negative Z is forward. Getting this backwards steers the car with its
	# rear wheels and flips aero balance, without changing any magnitude a
	# test might otherwise check.
	assert_lt(_setup.front_axle_z(), 0.0)
	assert_gt(_setup.rear_axle_z(), 0.0)


func test_centre_of_mass_sits_below_the_chassis_origin() -> void:
	assert_lt(_setup.center_of_mass_offset().y, 0.0)


func test_four_wheels_are_placed_symmetrically() -> void:
	var offsets := _setup.wheel_offsets()
	assert_eq(offsets.size(), 4)
	assert_almost_eq(offsets[0].x, -offsets[1].x, 0.001)
	assert_almost_eq(offsets[2].x, -offsets[3].x, 0.001)
