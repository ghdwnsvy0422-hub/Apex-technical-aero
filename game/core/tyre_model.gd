class_name TyreModel
extends RefCounted
## Slip-based tyre force model (simplified Pacejka).
##
## Pure math with no engine dependencies so the curves can be tested and swept
## headlessly. Everything here returns normalised coefficients in -1..1; the
## caller scales them by the grip limit for the wheel's current load.

const LONG_B: float = 12.0
const LONG_C: float = 1.60
const LONG_E: float = 0.60

# Tuned so lateral grip peaks near 8 degrees of slip, where a slick actually
# peaks. A softer curve put the peak past 25 degrees, which drives like ice:
# the car has to be well sideways before it generates its best grip.
const LAT_B: float = 23.0
const LAT_C: float = 1.40
const LAT_E: float = 0.60

## Slip is a ratio against forward speed, which collapses towards zero at a
## standstill. Dividing by the raw speed there produces enormous slip values
## and a car that launches itself, so the denominator is floored.
const LOW_SPEED_REFERENCE: float = 2.0

## Load at which the friction coefficient equals its nominal value. Set to a
## typical static corner load so a car at rest sits at its rated grip.
const REFERENCE_LOAD: float = 2000.0


static func magic_formula(slip: float, b: float, c: float, e: float) -> float:
	var scaled := b * slip
	return sin(c * atan(scaled - e * (scaled - atan(scaled))))


static func longitudinal_coefficient(slip_ratio_value: float) -> float:
	return magic_formula(slip_ratio_value, LONG_B, LONG_C, LONG_E)


static func lateral_coefficient(slip_angle_value: float) -> float:
	return magic_formula(slip_angle_value, LAT_B, LAT_C, LAT_E)


## Longitudinal and lateral demand share one contact patch, so their combined
## magnitude is clamped to the friction circle. Without this a car could brake
## at the limit and corner at the limit simultaneously.
static func combined_coefficients(slip_ratio_value: float, slip_angle_value: float) -> Vector2:
	var demand := Vector2(
		longitudinal_coefficient(slip_ratio_value),
		lateral_coefficient(slip_angle_value)
	)
	var magnitude := demand.length()
	if magnitude > 1.0:
		demand /= magnitude
	return demand


## Peak force a wheel can transmit at this load. Grip rises sub-linearly with
## load, which is why weight transfer costs the car total grip and why smooth
## inputs are quicker than violent ones (PRD 30).
static func grip_limit(load: float, friction: float, sensitivity: float) -> float:
	if load <= 0.0:
		return 0.0
	return friction * REFERENCE_LOAD * pow(load / REFERENCE_LOAD, sensitivity)


static func slip_ratio(contact_speed: float, ground_speed: float) -> float:
	return (contact_speed - ground_speed) / maxf(absf(ground_speed), LOW_SPEED_REFERENCE)


static func slip_angle(lateral_speed: float, longitudinal_speed: float) -> float:
	return atan2(-lateral_speed, maxf(absf(longitudinal_speed), LOW_SPEED_REFERENCE))
