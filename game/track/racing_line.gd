class_name RacingLine
extends RefCounted

const DEFAULT_SPACING_M: float = 4.0
const DEFAULT_EDGE_MARGIN_M: float = 1.2
const RELAXATION: float = 0.4
const SMOOTHING_PASSES: int = 300

const DEFAULT_LATERAL_G: float = 2.2
const DEFAULT_BRAKING_G: float = 2.0
const DEFAULT_ACCELERATION_G: float = 0.55
const DEFAULT_TOP_SPEED_KPH: float = 350.0
const GRAVITY: float = 9.8

var points: Array[Vector3] = []
var lateral_m: PackedFloat32Array = PackedFloat32Array()
var curvature: PackedFloat32Array = PackedFloat32Array()
var speed_mps: PackedFloat32Array = PackedFloat32Array()
var corridor_m: float = 0.0
var sample_spacing_m: float = 0.0
var centreline_length_m: float = 0.0

var _frames: Array[Transform3D] = []


static func from_curve(
	curve: Curve3D,
	half_width_m: float,
	spacing_m: float = DEFAULT_SPACING_M,
	edge_margin_m: float = DEFAULT_EDGE_MARGIN_M
) -> RacingLine:
	var line := RacingLine.new()
	var frames := TrackGeometry.sample_frames(curve, spacing_m)
	if frames.size() < 3:
		return line

	line._frames = frames
	line.centreline_length_m = curve.get_baked_length()
	line.sample_spacing_m = line.centreline_length_m / float(frames.size())
	line.corridor_m = maxf(half_width_m - edge_margin_m, 0.0)
	line.lateral_m.resize(frames.size())
	line._relax()
	line._rebuild()
	line.compute_speeds()
	return line


func compute_speeds(
	lateral_g: float = DEFAULT_LATERAL_G,
	braking_g: float = DEFAULT_BRAKING_G,
	acceleration_g: float = DEFAULT_ACCELERATION_G,
	top_speed_kph: float = DEFAULT_TOP_SPEED_KPH
) -> void:
	var count := points.size()
	speed_mps.resize(count)
	if count < 3:
		return

	var top_speed := top_speed_kph / 3.6
	for index: int in count:
		var bend := curvature[index]
		if bend < 0.000001:
			speed_mps[index] = top_speed
		else:
			speed_mps[index] = minf(top_speed, sqrt(lateral_g * GRAVITY / bend))

	for _lap: int in 2:
		for index: int in count:
			var ahead := posmod(index + 1, count)
			var step := points[index].distance_to(points[ahead])
			speed_mps[ahead] = minf(
				speed_mps[ahead], _reachable(speed_mps[index], acceleration_g, step)
			)
		for reverse: int in count:
			var index := count - 1 - reverse
			var ahead := posmod(index + 1, count)
			var step := points[index].distance_to(points[ahead])
			speed_mps[index] = minf(speed_mps[index], _reachable(speed_mps[ahead], braking_g, step))


func index_for_offset(centreline_offset_m: float) -> int:
	if points.is_empty() or sample_spacing_m <= 0.0:
		return 0
	return posmod(int(floor(centreline_offset_m / sample_spacing_m)), points.size())


func point_for_offset(centreline_offset_m: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	return points[index_for_offset(centreline_offset_m)]


func speed_for_offset(centreline_offset_m: float) -> float:
	if speed_mps.is_empty():
		return 0.0
	return speed_mps[index_for_offset(centreline_offset_m)]


func length_m() -> float:
	var total := 0.0
	for index: int in points.size():
		total += points[index].distance_to(points[posmod(index + 1, points.size())])
	return total


func total_curvature() -> float:
	var total := 0.0
	for index: int in points.size():
		var step := points[index].distance_to(points[posmod(index + 1, points.size())])
		total += curvature[index] * step
	return total


func estimated_lap_seconds() -> float:
	var total := 0.0
	for index: int in points.size():
		var step := points[index].distance_to(points[posmod(index + 1, points.size())])
		total += step / maxf(speed_mps[index], 1.0)
	return total


static func menger_curvature(first: Vector3, second: Vector3, third: Vector3) -> float:
	var a := first.distance_to(second)
	var b := second.distance_to(third)
	var c := third.distance_to(first)
	var denominator := a * b * c
	if denominator < 0.000001:
		return 0.0
	return 2.0 * (second - first).cross(third - first).length() / denominator


func _reachable(from_speed: float, limit_g: float, distance_m: float) -> float:
	return sqrt(from_speed * from_speed + 2.0 * limit_g * GRAVITY * distance_m)


func _world(index: int) -> Vector3:
	var frame := _frames[index]
	return frame.origin + frame.basis.x * lateral_m[index]


func _relax() -> void:
	if corridor_m <= 0.0:
		return
	var count := _frames.size()
	for _pass: int in SMOOTHING_PASSES:
		for index: int in count:
			var behind := _world(posmod(index - 1, count))
			var ahead := _world(posmod(index + 1, count))
			var frame := _frames[index]
			var desired := ((behind + ahead) * 0.5 - frame.origin).dot(frame.basis.x)
			lateral_m[index] = clampf(
				lateral_m[index] + (desired - lateral_m[index]) * RELAXATION,
				-corridor_m,
				corridor_m
			)


func _rebuild() -> void:
	var count := _frames.size()
	points.resize(count)
	curvature.resize(count)
	for index: int in count:
		points[index] = _world(index)
	for index: int in count:
		curvature[index] = menger_curvature(
			points[posmod(index - 1, count)], points[index], points[posmod(index + 1, count)]
		)
