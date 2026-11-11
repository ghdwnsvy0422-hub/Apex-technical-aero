extends GutTest
## Track cross-section and sweep geometry.

var _profile: TrackProfile


func before_each() -> void:
	_profile = TrackProfile.new()


## Built directly rather than through CurveBuilder, which always closes the
## loop and would fold a straight line back on itself.
func _straight_curve() -> Curve3D:
	var curve := Curve3D.new()
	for step: int in 40:
		curve.add_point(Vector3(0.0, 0.0, float(step) * 10.0))
	return curve


# --- profile ---------------------------------------------------------------

func test_bands_run_edge_to_edge_without_gaps() -> void:
	# A gap between two bands is a hole the car falls through, and an overlap
	# is z-fighting plus an ambiguous surface lookup.
	var bands := _profile.bands()
	for index: int in bands.size() - 1:
		assert_almost_eq(
			(bands[index]["outer"] as Vector2).distance_to(bands[index + 1]["inner"]),
			0.0, 0.0001,
			"band %d does not meet band %d" % [index, index + 1]
		)


func test_profile_is_symmetric_about_the_centreline() -> void:
	var bands := _profile.bands()
	assert_eq(bands.size(), 7)
	assert_almost_eq(
		(bands[0]["inner"] as Vector2).x, -(bands[6]["outer"] as Vector2).x, 0.0001
	)
	assert_almost_eq(
		(bands[2]["inner"] as Vector2).x, -(bands[4]["outer"] as Vector2).x, 0.0001
	)


func test_road_spans_the_full_width() -> void:
	var road := _profile.bands()[3]
	assert_eq(road["surface"], TrackProfile.Surface.ROAD)
	assert_almost_eq(
		(road["outer"] as Vector2).x - (road["inner"] as Vector2).x,
		_profile.road_half_width * 2.0, 0.0001
	)


func test_leaving_the_road_costs_grip() -> void:
	# PRD 60: the racing line has to be worth holding.
	var road: float = TrackProfile.FRICTION[TrackProfile.Surface.ROAD]
	assert_lt(TrackProfile.FRICTION[TrackProfile.Surface.KERB], road)
	assert_lt(TrackProfile.FRICTION[TrackProfile.Surface.RUNOFF], road)


func test_kerbs_stay_driveable() -> void:
	# A kerb that behaves like gravel stops anyone attacking one.
	assert_gt(
		TrackProfile.FRICTION[TrackProfile.Surface.KERB],
		TrackProfile.FRICTION[TrackProfile.Surface.RUNOFF]
	)


# --- sweep frames ----------------------------------------------------------

func test_frames_are_orthonormal() -> void:
	var frames := TrackGeometry.sample_frames(_straight_curve(), 8.0)
	assert_gt(frames.size(), 10)
	for frame: Transform3D in frames:
		assert_almost_eq(frame.basis.x.length(), 1.0, 0.001)
		assert_almost_eq(frame.basis.y.length(), 1.0, 0.001)
		assert_almost_eq(frame.basis.x.dot(frame.basis.y), 0.0, 0.001)
		assert_almost_eq(frame.basis.y.dot(frame.basis.z), 0.0, 0.001)


func test_frames_follow_the_curve_direction() -> void:
	var frames := TrackGeometry.sample_frames(_straight_curve(), 8.0)
	var forward := frames[0].basis * Vector3.FORWARD
	assert_almost_eq(forward.dot(Vector3.BACK), 1.0, 0.01)


func test_sampling_spacing_controls_density() -> void:
	var curve := _straight_curve()
	var coarse := TrackGeometry.sample_frames(curve, 20.0)
	var fine := TrackGeometry.sample_frames(curve, 5.0)
	assert_gt(fine.size(), coarse.size())


func test_empty_curve_produces_no_frames() -> void:
	assert_eq(TrackGeometry.sample_frames(Curve3D.new(), 8.0).size(), 0)


# --- band sweep ------------------------------------------------------------

func test_closed_band_wraps_back_to_the_start() -> void:
	var frames := TrackGeometry.sample_frames(CurveBuilder.oval(200.0, 80.0), 8.0)
	var closed: Dictionary = TrackGeometry.build_band(
		frames, Vector2(-7.5, 0.0), Vector2(7.5, 0.0), true
	)
	var open: Dictionary = TrackGeometry.build_band(
		frames, Vector2(-7.5, 0.0), Vector2(7.5, 0.0), false
	)
	# One extra span joins the last cross-section back to the first.
	assert_eq(
		(closed["faces"] as PackedVector3Array).size()
		- (open["faces"] as PackedVector3Array).size(),
		6
	)


func test_band_emits_two_triangles_per_span() -> void:
	var frames := TrackGeometry.sample_frames(_straight_curve(), 10.0)
	var built: Dictionary = TrackGeometry.build_band(
		frames, Vector2(-7.5, 0.0), Vector2(7.5, 0.0), false
	)
	assert_eq((built["faces"] as PackedVector3Array).size(), (frames.size() - 1) * 6)
	assert_not_null(built["mesh"])


func test_band_needs_at_least_two_frames() -> void:
	var built: Dictionary = TrackGeometry.build_band(
		[], Vector2.ZERO, Vector2.ONE, false
	)
	assert_null(built["mesh"])


# --- curve builder ---------------------------------------------------------

func test_oval_closes_on_itself() -> void:
	var curve := CurveBuilder.oval(400.0, 120.0)
	var start := curve.get_point_position(0)
	var last := curve.get_point_position(curve.point_count - 1)
	assert_lt(start.distance_to(last), CurveBuilder.POINT_SPACING * 1.5)


func test_oval_length_matches_its_geometry() -> void:
	var straight := 400.0
	var radius := 120.0
	var curve := CurveBuilder.oval(straight, radius)
	var expected := 2.0 * straight + TAU * radius
	assert_almost_eq(curve.get_baked_length(), expected, expected * 0.03)


func test_banking_is_blended_rather_than_stepped() -> void:
	# A step change in tilt reads as the road twisting under the car.
	var curve := CurveBuilder.oval(400.0, 120.0, 8.0)
	var biggest_step := 0.0
	for index: int in curve.point_count:
		var here := curve.get_point_tilt(index)
		var next := curve.get_point_tilt((index + 1) % curve.point_count)
		biggest_step = maxf(biggest_step, absf(next - here))
	assert_lt(biggest_step, deg_to_rad(8.0) / 2.0)


func test_flat_track_has_no_tilt() -> void:
	var curve := CurveBuilder.oval(400.0, 120.0, 0.0)
	for index: int in curve.point_count:
		assert_eq(curve.get_point_tilt(index), 0.0)
