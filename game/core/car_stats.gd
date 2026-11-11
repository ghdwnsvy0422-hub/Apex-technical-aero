class_name CarStats
extends RefCounted
## Canonical identifiers for car stats, part slots, and rarities (PRD 23-25).
##
## Stat values are 0-100 ratings, not physical units. Translating a rating into
## a physics parameter is Phase 3.2's job and lives in one place so the
## trade-off curves (PRD 27) stay auditable.

const STATS: Array[String] = [
	"top_speed",
	"acceleration",
	"braking",
	"cornering",
	"downforce",
	"drag",
	"stability",
	"tyre_wear",
	"brake_wear",
	"engine_durability",
	"energy_recovery",
	"energy_output",
]

const SLOTS: Array[String] = [
	"engine",
	"front_wing",
	"rear_wing",
	"tyres",
	"suspension",
	"brakes",
	"gearbox",
	"energy_system",
	"chassis",
]

## Ordered worst to best. Higher rarity widens the tuning range rather than
## raising raw stats (PRD 26), so this order must never imply raw superiority.
const RARITIES: Array[String] = [
	"common",
	"rare",
	"epic",
	"legendary",
]

## Setup sliders the player tunes directly (PRD 22), each owned by one slot.
const SETUP_SLIDERS: Dictionary = {
	"front_wing": "front_wing",
	"rear_wing": "rear_wing",
	"gear_ratio": "gearbox",
	"suspension": "suspension",
	"brake_balance": "brakes",
}

## Stats where a high rating is a drawback. UI must invert these when drawing
## bars, and the setup recommender must not treat them as goals to maximise.
const LOWER_IS_BETTER: Array[String] = [
	"drag",
	"tyre_wear",
	"brake_wear",
]

const RATING_MIN: int = 0
const RATING_MAX: int = 100


static func is_stat(id: String) -> bool:
	return STATS.has(id)


static func is_slot(id: String) -> bool:
	return SLOTS.has(id)


static func is_rarity(id: String) -> bool:
	return RARITIES.has(id)
