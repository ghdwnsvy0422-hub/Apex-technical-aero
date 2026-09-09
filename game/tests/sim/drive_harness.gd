class_name DriveHarness
extends Node3D
## Minimal world for driving a car headlessly: one flat surface and one car.
##
## Phase 1.7 grows this into the AI-driver lap-time rig; for now it exists so
## the physics can be measured rather than eyeballed.

var car: CarBody

const GROUND_SIZE: float = 8000.0
const GROUND_THICKNESS: float = 4.0


func _init(setup: CarSetup = null) -> void:
	_build_ground()
	car = CarBody.new()
	if setup != null:
		car.setup = setup
	# Spawn a little above the contact plane and let the suspension settle,
	# rather than guessing the static ride height.
	car.position = Vector3(0.0, car.setup.contact_depth() + 0.15, 0.0)
	add_child(car)


## Holds `input` for `ticks` physics steps.
func drive(input: DriverInput, ticks: int) -> void:
	car.input = input
	for _i: int in ticks:
		await get_tree().physics_frame


func coast(ticks: int) -> void:
	await drive(DriverInput.new(), ticks)


func total_wheel_load() -> float:
	var total := 0.0
	for wheel: Wheel in car.wheels:
		total += wheel.load
	return total


func ride_height() -> float:
	return car.global_position.y - car.setup.contact_depth()


func _build_ground() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, GROUND_THICKNESS, GROUND_SIZE)

	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.0, -GROUND_THICKNESS * 0.5, 0.0)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.add_child(shape)
	add_child(ground)
