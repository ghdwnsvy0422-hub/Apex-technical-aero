class_name PlayerInput
extends Node
## Turns device input into a DriverInput value.
##
## Lives outside `core` on purpose: the dedicated server replays inputs and the
## AI driver synthesises them, and neither may touch `Input` (CLAUDE.md rule 1).

## Keys are on or off, so raw keyboard steering would snap to full lock in one
## tick and make the car impossible to place. Rates are fast enough not to feel
## like lag: full lock in roughly a quarter second.
const STEER_RATE: float = 4.0
## Returning to centre is quicker than steering in, which is what lets a
## correction be caught rather than overshot.
const STEER_CENTRE_RATE: float = 7.0
const PEDAL_RATE: float = 8.0

var _steer: float = 0.0
var _throttle: float = 0.0
var _brake: float = 0.0


func poll(delta: float) -> DriverInput:
	var steer_target := Input.get_axis("steer_left", "steer_right")
	return _advance(
		steer_target,
		Input.get_action_strength("throttle"),
		Input.get_action_strength("brake"),
		Input.is_action_pressed("energy_boost"),
		delta
	)


func reset() -> void:
	_steer = 0.0
	_throttle = 0.0
	_brake = 0.0


## Split from `poll` so the smoothing can be tested without a device attached.
func _advance(
	steer_target: float, throttle_target: float, brake_target: float,
	energy: bool, delta: float
) -> DriverInput:
	var returning := absf(steer_target) < 0.01 or signf(steer_target) != signf(_steer)
	var steer_rate := STEER_CENTRE_RATE if returning else STEER_RATE

	_steer = move_toward(_steer, steer_target, steer_rate * delta)
	_throttle = move_toward(_throttle, throttle_target, PEDAL_RATE * delta)
	_brake = move_toward(_brake, brake_target, PEDAL_RATE * delta)

	return DriverInput.create(_throttle, _brake, _steer, energy)
