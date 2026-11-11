class_name TrackLayout
extends RefCounted

const SAMPLE_SPACING: float = 8.0

var positions: Array[Vector3] = []
var banking: PackedFloat32Array = PackedFloat32Array()
var end_position: Vector3 = Vector3.ZERO
var end_heading_rad: float = 0.0


static func from_track(track: Dictionary, spacing: float = SAMPLE_SPACING) -> TrackLayout:
	var layout := TrackLayout.new()
	var cursor := Vector3.ZERO
	var heading: float = 0.0
	var step := maxf(spacing, 1.0)

	for entry: Variant in track.get("segments", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var segment := entry as Dictionary
		match str(segment.get("kind", "")):
			"straight":
				cursor = layout._add_straight(segment, cursor, heading, step)
			"chicane":
				cursor = layout._add_chicane(segment, cursor, heading, step)
			"corner":
				cursor = layout._add_corner(segment, cursor, heading, step)
				heading += deg_to_rad(float(segment.get("angle_deg", 0.0)))

	layout.end_position = cursor
	layout.end_heading_rad = heading
	return layout


static func direction_of(heading_rad: float) -> Vector3:
	return Vector3(sin(heading_rad), 0.0, -cos(heading_rad))


static func right_of(heading_rad: float) -> Vector3:
	return Vector3(cos(heading_rad), 0.0, sin(heading_rad))


static func rotate_clockwise(offset: Vector3, angle_rad: float) -> Vector3:
	return offset.rotated(Vector3.UP, -angle_rad)


func closure_gap_m() -> float:
	if positions.is_empty():
		return 0.0
	return end_position.distance_to(positions[0])


func heading_error_deg() -> float:
	return absf(absf(rad_to_deg(end_heading_rad)) - 360.0)


func _add_straight(segment: Dictionary, from: Vector3, heading: float, spacing: float) -> Vector3:
	var span := float(segment.get("length_m", 0.0))
	var rise := float(segment.get("elevation_m", 0.0))
	var to := from + direction_of(heading) * span + Vector3.UP * rise
	var steps := maxi(int(round(span / spacing)), 1)
	for index: int in steps:
		positions.append(from.lerp(to, float(index) / float(steps)))
		banking.append(0.0)
	return to


func _add_chicane(segment: Dictionary, from: Vector3, heading: float, spacing: float) -> Vector3:
	var span := float(segment.get("length_m", 0.0))
	var offset := float(segment.get("offset_m", 0.0))
	var rise := float(segment.get("elevation_m", 0.0))
	var forward := direction_of(heading)
	var sideways := right_of(heading)
	var steps := maxi(int(round(span / spacing)), 2)
	for index: int in steps:
		var travelled := float(index) / float(steps)
		positions.append(
			from
			+ forward * (span * travelled)
			+ sideways * (offset * sin(PI * travelled))
			+ Vector3.UP * (rise * travelled)
		)
		banking.append(0.0)
	return from + forward * span + Vector3.UP * rise


func _add_corner(segment: Dictionary, from: Vector3, heading: float, spacing: float) -> Vector3:
	var turn := deg_to_rad(float(segment.get("angle_deg", 0.0)))
	var radius := float(segment.get("radius_m", 0.0))
	var rise := float(segment.get("elevation_m", 0.0))
	var bank := deg_to_rad(float(segment.get("banking_deg", 0.0)))
	var centre := from + right_of(heading) * radius * signf(turn)
	var spoke := from - centre
	var steps := maxi(int(round(absf(turn) * radius / spacing)), 2)

	for index: int in steps:
		var travelled := float(index) / float(steps)
		positions.append(
			centre + rotate_clockwise(spoke, turn * travelled) + Vector3.UP * (rise * travelled)
		)
		banking.append(bank)

	return centre + rotate_clockwise(spoke, turn) + Vector3.UP * rise
