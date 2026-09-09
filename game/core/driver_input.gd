class_name DriverInput
extends RefCounted
## One tick of driver intent, passed into the simulation by value.
##
## The core never reads `Input` directly (see CLAUDE.md rule 1): the dedicated
## server replays inputs that arrived over the network and the AI driver
## synthesises them, so both must be able to produce this without a keyboard.

## 0..1
var throttle: float = 0.0
## 0..1
var brake: float = 0.0
## -1 (left) .. 1 (right)
var steer: float = 0.0
var energy: bool = false


static func create(
	throttle: float, brake: float, steer: float, energy: bool = false
) -> DriverInput:
	var input := DriverInput.new()
	input.throttle = clampf(throttle, 0.0, 1.0)
	input.brake = clampf(brake, 0.0, 1.0)
	input.steer = clampf(steer, -1.0, 1.0)
	input.energy = energy
	return input


func duplicate_input() -> DriverInput:
	return DriverInput.create(throttle, brake, steer, energy)
