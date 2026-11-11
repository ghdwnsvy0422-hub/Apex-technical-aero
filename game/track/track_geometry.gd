class_name TrackGeometry
extends RefCounted
## Sweeps a cross-section along a Curve3D to produce meshes and collision.
##
## Pure geometry with no scene-tree dependencies so it can be exercised
## headlessly and reused by the server, which needs the collision but none of
## the meshes.


## A frame is the local axes at one point on the centreline: basis.x is right,
## basis.y is up (banked), and the curve runs towards -basis.z.
static func sample_frames(curve: Curve3D, spacing: float) -> Array[Transform3D]:
	var frames: Array[Transform3D] = []
	var length := curve.get_baked_length()
	if length <= 0.0 or spacing <= 0.0:
		return frames

	var count := maxi(int(ceil(length / spacing)), 3)
	for index: int in count:
		frames.append(frame_at(curve, length * float(index) / count, length))
	return frames


static func frame_at(curve: Curve3D, offset: float, length: float) -> Transform3D:
	var origin := curve.sample_baked(offset)
	var ahead := curve.sample_baked(fmod(offset + 0.5, length))
	var forward := ahead - origin
	if forward.length_squared() < 0.000001:
		forward = Vector3.FORWARD
	forward = forward.normalized()

	var up := curve.sample_baked_up_vector(offset, true).normalized()
	var right := forward.cross(up)
	if right.length_squared() < 0.000001:
		right = Vector3.RIGHT
	right = right.normalized()
	# Re-orthogonalise: the sampled up vector is only approximately square to
	# the tangent, and the error shows up as a twisting road surface.
	up = right.cross(forward).normalized()

	return Transform3D(Basis(right, up, -forward), origin)


## Builds one longitudinal band between two cross-section points.
## Returns {"mesh": ArrayMesh, "faces": PackedVector3Array}.
static func build_band(
	frames: Array[Transform3D], inner: Vector2, outer: Vector2, closed: bool
) -> Dictionary:
	var empty := {"mesh": null, "faces": PackedVector3Array()}
	var count := frames.size()
	if count < 2:
		return empty

	var spans := count if closed else count - 1
	var faces := PackedVector3Array()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var distance := 0.0
	for index: int in spans:
		var here := frames[index]
		var next := frames[(index + 1) % count]

		var a_inner := _project(here, inner)
		var a_outer := _project(here, outer)
		var b_inner := _project(next, inner)
		var b_outer := _project(next, outer)

		var step := here.origin.distance_to(next.origin)
		# Metres map straight to UV units so kerb stripes and road markings keep
		# a constant size whatever the corner radius.
		var v_here := distance
		var v_next := distance + step
		distance = v_next

		_add_triangle(surface, faces,
			a_inner, a_outer, b_outer,
			Vector2(0.0, v_here), Vector2(1.0, v_here), Vector2(1.0, v_next))
		_add_triangle(surface, faces,
			a_inner, b_outer, b_inner,
			Vector2(0.0, v_here), Vector2(1.0, v_next), Vector2(0.0, v_next))

	surface.generate_normals()
	surface.generate_tangents()
	return {"mesh": surface.commit(), "faces": faces}


## Total centreline length, for lap distance and sector splits.
static func measure(curve: Curve3D) -> float:
	return curve.get_baked_length()


static func _project(frame: Transform3D, station: Vector2) -> Vector3:
	return frame.origin + frame.basis.x * station.x + frame.basis.y * station.y


static func _add_triangle(
	surface: SurfaceTool, faces: PackedVector3Array,
	a: Vector3, b: Vector3, c: Vector3,
	uv_a: Vector2, uv_b: Vector2, uv_c: Vector2
) -> void:
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)
	faces.append(a)
	faces.append(b)
	faces.append(c)
