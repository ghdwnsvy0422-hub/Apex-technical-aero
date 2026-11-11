class_name TrackProfile
extends RefCounted
## Cross-section of a track: road, kerbs, runoff and barrier.
##
## The profile is swept along the centreline spline to generate every surface,
## so track shape is a curve and track *character* is these numbers. Widening
## the runoff or lowering a kerb is a data change, never new geometry code.

enum Surface { ROAD, KERB, RUNOFF, BARRIER }

## Grip multiplier applied on top of the tyre's own friction. Leaving the road
## has to cost time without being an instant spin, or drivers stop attacking
## kerbs at all.
const FRICTION: Dictionary = {
	Surface.ROAD: 1.0,
	Surface.KERB: 0.88,
	Surface.RUNOFF: 0.55,
	Surface.BARRIER: 0.40,
}

const SURFACE_NAMES: Dictionary = {
	Surface.ROAD: "road",
	Surface.KERB: "kerb",
	Surface.RUNOFF: "runoff",
	Surface.BARRIER: "barrier",
}

var road_half_width: float = 7.5
var kerb_width: float = 1.20
var kerb_height: float = 0.07
var runoff_width: float = 14.0
## Runoff falls away from the track so a car that leaves it loses downforce
## and settles, rather than skating on at racing speed.
var runoff_drop: float = 0.25
var barrier_height: float = 1.15

## Distance between swept cross-sections. Smaller is smoother and heavier.
var sample_spacing: float = 4.0


func kerb_edge() -> float:
	return road_half_width + kerb_width


func runoff_edge() -> float:
	return kerb_edge() + runoff_width


## Bands are (lateral, height) pairs in the cross-section plane, ordered from
## the left barrier across to the right.
func bands() -> Array[Dictionary]:
	var half := road_half_width
	var kerb := kerb_edge()
	var runoff := runoff_edge()
	var barrier_base := -runoff_drop
	var barrier_top := barrier_base + barrier_height

	return [
		_band(Surface.BARRIER,
			Vector2(-runoff, barrier_top), Vector2(-runoff, barrier_base)),
		_band(Surface.RUNOFF,
			Vector2(-runoff, barrier_base), Vector2(-kerb, kerb_height)),
		_band(Surface.KERB,
			Vector2(-kerb, kerb_height), Vector2(-half, 0.0)),
		_band(Surface.ROAD,
			Vector2(-half, 0.0), Vector2(half, 0.0)),
		_band(Surface.KERB,
			Vector2(half, 0.0), Vector2(kerb, kerb_height)),
		_band(Surface.RUNOFF,
			Vector2(kerb, kerb_height), Vector2(runoff, barrier_base)),
		_band(Surface.BARRIER,
			Vector2(runoff, barrier_base), Vector2(runoff, barrier_top)),
	]


func _band(surface: Surface, inner: Vector2, outer: Vector2) -> Dictionary:
	return {"surface": surface, "inner": inner, "outer": outer}
