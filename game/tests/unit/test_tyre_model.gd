extends GutTest
## The tyre curve decides how the car behaves at and past the limit, so its
## shape is pinned here rather than left to be judged by feel.


func test_no_slip_produces_no_force() -> void:
	assert_almost_eq(TyreModel.longitudinal_coefficient(0.0), 0.0, 0.0001)
	assert_almost_eq(TyreModel.lateral_coefficient(0.0), 0.0, 0.0001)


func test_longitudinal_grip_peaks_at_a_small_slip_ratio() -> void:
	var peak_slip := 0.0
	var peak_value := 0.0
	for step: int in 200:
		var slip := float(step) * 0.01
		var value: float = TyreModel.longitudinal_coefficient(slip)
		if value > peak_value:
			peak_value = value
			peak_slip = slip
	assert_between(peak_slip, 0.05, 0.20, "peak should sit at a few percent slip")
	assert_almost_eq(peak_value, 1.0, 0.05)


func test_grip_falls_away_past_the_peak() -> void:
	# This tail is what makes a spinning wheel keep spinning; if it vanished,
	# wheelspin and lockup would carry no penalty.
	assert_lt(
		TyreModel.longitudinal_coefficient(1.5),
		TyreModel.longitudinal_coefficient(0.12)
	)


func test_lateral_grip_peaks_at_a_small_slip_angle() -> void:
	var peak_angle := 0.0
	var peak_value := 0.0
	for step: int in 100:
		var angle := float(step) * 0.005
		var value: float = TyreModel.lateral_coefficient(angle)
		if value > peak_value:
			peak_value = value
			peak_angle = angle
	assert_between(rad_to_deg(peak_angle), 3.0, 15.0, "peak slip angle in degrees")


func test_curves_are_odd_functions() -> void:
	assert_almost_eq(
		TyreModel.longitudinal_coefficient(-0.3),
		-TyreModel.longitudinal_coefficient(0.3),
		0.0001
	)


func test_combined_demand_stays_inside_the_friction_circle() -> void:
	for ratio_step: int in 20:
		for angle_step: int in 20:
			var combined := TyreModel.combined_coefficients(
				float(ratio_step) * 0.1, float(angle_step) * 0.05
			)
			assert_lte(combined.length(), 1.0001,
				"slip %.2f / %.2f exceeded the friction circle" % [
					float(ratio_step) * 0.1, float(angle_step) * 0.05
				])


func test_grip_equals_nominal_friction_at_the_reference_load() -> void:
	assert_almost_eq(
		TyreModel.grip_limit(TyreModel.REFERENCE_LOAD, 1.7, 0.85),
		1.7 * TyreModel.REFERENCE_LOAD,
		0.01
	)


func test_grip_rises_sub_linearly_with_load() -> void:
	# Why weight transfer costs a car total grip, and why smooth inputs are
	# quicker than violent ones (PRD 30).
	var single: float = TyreModel.grip_limit(2000.0, 1.7, 0.85)
	var doubled: float = TyreModel.grip_limit(4000.0, 1.7, 0.85)
	assert_gt(doubled, single)
	assert_lt(doubled, single * 2.0)


func test_unloaded_wheel_has_no_grip() -> void:
	assert_eq(TyreModel.grip_limit(0.0, 1.7, 0.85), 0.0)


func test_slip_ratio_stays_finite_at_a_standstill() -> void:
	# Dividing by the true speed here would produce enormous slip and launch
	# the car off the line.
	var slip: float = TyreModel.slip_ratio(5.0, 0.0)
	assert_lt(absf(slip), 10.0)


func test_slip_angle_opposes_the_direction_of_slide() -> void:
	assert_lt(TyreModel.slip_angle(5.0, 50.0), 0.0)
	assert_gt(TyreModel.slip_angle(-5.0, 50.0), 0.0)
