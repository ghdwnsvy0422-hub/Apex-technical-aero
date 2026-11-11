class_name CarVisuals
extends Node3D
## Placeholder bodywork built from primitives (PRODUCTION_PLAN part B-2 stage 1).
##
## Purely presentational and driven from the simulation each frame, so swapping
## in real meshes later changes only this file.

const BODY_COLOUR := Color(0.10, 0.45, 0.85)
const ACCENT_COLOUR := Color(0.95, 0.62, 0.10)
const TYRE_COLOUR := Color(0.09, 0.09, 0.10)

var car: CarBody

var _wheel_pivots: Array[Node3D] = []
var _wheel_spinners: Array[Node3D] = []
var _spin_angles: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	if car == null:
		return
	_build_chassis()
	_build_wheels()


func _process(delta: float) -> void:
	if car == null:
		return
	global_transform = car.global_transform
	_update_wheels(delta)


func _update_wheels(delta: float) -> void:
	var setup := car.setup
	for index: int in car.wheels.size():
		var wheel := car.wheels[index]
		var pivot := _wheel_pivots[index]

		# The hub hangs below its mount by whatever the suspension has left,
		# so compression shows as the wheel rising into the body.
		var drop := setup.suspension_rest_length - wheel.compression
		pivot.position = wheel.offset - Vector3(0.0, drop, 0.0)
		pivot.rotation.y = -wheel.steer_angle

		_spin_angles[index] += wheel.angular_velocity * delta
		_wheel_spinners[index].rotation.x = _spin_angles[index]


func _build_chassis() -> void:
	var setup := car.setup
	# The chassis origin sits at the suspension mounts, so bodywork is placed
	# relative to the contact plane below it rather than to the origin.
	var floor_y := -setup.contact_depth()

	_add_box(
		Vector3(0.0, floor_y + 0.42, -0.35),
		Vector3(0.72, 0.45, 2.90),
		BODY_COLOUR
	)
	_add_box(
		Vector3(0.0, floor_y + 0.30, setup.front_axle_z() * 0.55),
		Vector3(0.42, 0.22, 1.70),
		BODY_COLOUR
	)
	_add_box(
		Vector3(0.0, floor_y + 0.16, setup.front_axle_z() - 0.35),
		Vector3(1.55, 0.06, 0.55),
		ACCENT_COLOUR
	)
	# Endplates give the rear wing a silhouette, which is what makes the car's
	# facing readable in a screenshot.
	var wing_z := setup.rear_axle_z() - 0.30
	_add_box(Vector3(0.0, floor_y + 0.86, wing_z), Vector3(1.15, 0.07, 0.52), ACCENT_COLOUR)
	for side: float in [-1.0, 1.0]:
		_add_box(
			Vector3(side * 0.57, floor_y + 0.72, wing_z),
			Vector3(0.05, 0.36, 0.52),
			ACCENT_COLOUR
		)
	_add_box(
		Vector3(0.0, floor_y + 0.78, -0.10),
		Vector3(0.34, 0.34, 0.60),
		ACCENT_COLOUR
	)


func _build_wheels() -> void:
	var setup := car.setup
	var tyre := CylinderMesh.new()
	tyre.top_radius = setup.wheel_radius
	tyre.bottom_radius = setup.wheel_radius
	tyre.height = 0.38
	tyre.radial_segments = 20

	_spin_angles.resize(car.wheels.size())
	for wheel: Wheel in car.wheels:
		var pivot := Node3D.new()
		var spinner := Node3D.new()
		var mesh := MeshInstance3D.new()
		mesh.mesh = tyre
		mesh.material_override = _material(TYRE_COLOUR)
		# A cylinder stands on its Y axis; a wheel turns about the car's X.
		mesh.rotation.z = PI * 0.5

		spinner.add_child(mesh)
		pivot.add_child(spinner)
		add_child(pivot)

		_wheel_pivots.append(pivot)
		_wheel_spinners.append(spinner)


func _add_box(offset: Vector3, size: Vector3, colour: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.material_override = _material(colour)
	instance.position = offset
	add_child(instance)


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.25
	material.roughness = 0.45
	return material
