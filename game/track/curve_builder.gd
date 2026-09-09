class_name CurveBuilder
extends RefCounted
## Builds centreline curves. Phase 1.4 adds the JSON segment format on top of
## this; for now an oval exists so the sweep can be driven and looked at.

const POINT_SPACING: float = 8.0
## Points either side of a corner over which banking is blended in. A step
## change in tilt reads as the road visibly twisting under the car.
const BANK_BLEND_POINTS: int = 5


static func oval(straight_length: float, radius: float, banking_deg: float = 0.0) -> Curve3D:
	var positions: Array[Vector3] = []
	var in_corner: Array[bool] = []
	var half := straight_length * 0.5

	_add_straight(positions, in_corner, Vector3(radius, 0.0, -half), Vector3(radius, 0.0, half))
	_add_arc(positions, in_corner, Vector3(0.0, 0.0, half), radius, 0.0, PI)
	_add_straight(positions, in_corner, Vector3(-radius, 0.0, half), Vector3(-radius, 0.0, -half))
	_add_arc(positions, in_corner, Vector3(0.0, 0.0, -half), radius, PI, TAU)

	return from_points(positions, _blend_banking(in_corner, deg_to_rad(banking_deg)))


## Positions become a closed loop with smooth handles. Tilt banks the road:
## the sweep reads it through the curve's up vector.
static func from_points(positions: Array[Vector3], tilts: PackedFloat32Array) -> Curve3D:
	var curve := Curve3D.new()
	var count := positions.size()
	if count < 3:
		return curve

	for index: int in count:
		var previous := positions[(index - 1 + count) % count]
		var next := positions[(index + 1) % count]
		# Catmull-Rom style handles: a sixth of the span between neighbours is
		# the standard choice that keeps a circle of points looking circular.
		var handle := (next - previous) / 6.0
		curve.add_point(positions[index], -handle, handle)
		curve.set_point_tilt(index, tilts[index] if index < tilts.size() else 0.0)

	return curve


static func _add_straight(
	positions: Array[Vector3], in_corner: Array[bool], from: Vector3, to: Vector3
) -> void:
	var span := from.distance_to(to)
	var steps := maxi(int(round(span / POINT_SPACING)), 1)
	for step: int in steps:
		positions.append(from.lerp(to, float(step) / steps))
		in_corner.append(false)


static func _add_arc(
	positions: Array[Vector3], in_corner: Array[bool],
	centre: Vector3, radius: float, from_angle: float, to_angle: float
) -> void:
	var span := absf(to_angle - from_angle) * radius
	var steps := maxi(int(round(span / POINT_SPACING)), 2)
	for step: int in steps:
		var angle := lerpf(from_angle, to_angle, float(step) / steps)
		positions.append(centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
		in_corner.append(true)


## Averages the corner flag over a window so banking ramps in and out instead
## of switching on at the corner entry.
static func _blend_banking(in_corner: Array[bool], banking: float) -> PackedFloat32Array:
	var tilts := PackedFloat32Array()
	var count := in_corner.size()
	tilts.resize(count)
	if is_zero_approx(banking):
		return tilts

	for index: int in count:
		var total := 0.0
		for offset: int in range(-BANK_BLEND_POINTS, BANK_BLEND_POINTS + 1):
			total += 1.0 if in_corner[(index + offset + count) % count] else 0.0
		tilts[index] = banking * total / (2.0 * BANK_BLEND_POINTS + 1.0)
	return tilts
