class_name Aero
extends RefCounted
## Aerodynamic forces.
##
## Both scale with the square of speed, which is the mechanism behind PRD 27:
## wing area bought for cornering grip is paid for on the straights.

static func dynamic_pressure(speed: float, air_density: float) -> float:
	return 0.5 * air_density * speed * speed


## Total drag area including the induced drag the wings pay for their
## downforce. This coupling is what makes wing choice a trade-off (PRD 27)
## rather than free grip.
static func effective_drag_area(setup: CarSetup) -> float:
	return setup.drag_area + setup.induced_drag_factor * setup.downforce_area


static func drag(speed: float, setup: CarSetup) -> float:
	return dynamic_pressure(speed, setup.air_density) * effective_drag_area(setup)


static func downforce(speed: float, setup: CarSetup) -> float:
	return dynamic_pressure(speed, setup.air_density) * setup.downforce_area


static func load_ratio_per_speed_squared(setup: CarSetup, gravity: float) -> float:
	var weight := setup.mass * gravity
	if weight <= 0.0:
		return 0.0
	return 0.5 * setup.air_density * setup.downforce_area / weight
