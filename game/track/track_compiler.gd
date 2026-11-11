class_name TrackCompiler
extends RefCounted


static func curve_from(track: Dictionary, spacing: float = TrackLayout.SAMPLE_SPACING) -> Curve3D:
	var layout := TrackLayout.from_track(track, spacing)
	var tilts := CurveBuilder.smooth_loop(layout.banking, CurveBuilder.BANK_BLEND_POINTS)
	return CurveBuilder.from_points(closed_positions(layout), tilts)


static func closed_positions(layout: TrackLayout) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	positions.assign(layout.positions)
	var count := positions.size()
	if count < 2:
		return positions

	var drift := layout.end_position - positions[0]
	for index: int in count:
		positions[index] -= drift * (float(index) / float(count))
	return positions


static func build(track: Dictionary) -> Track:
	var node := Track.new()
	node.curve = curve_from(track)
	return node
