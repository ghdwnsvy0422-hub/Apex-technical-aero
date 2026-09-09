extends Node
## Loads and validates the JSON content in `res://data` (PRD 23-25, 28, 7).
##
## Content is data, not code, so a typo in a season's parts file would
## otherwise surface as a silently mis-specced car. Every file is validated at
## boot and the failures are reported, not swallowed.

const SCHEMA_VERSION: int = 1

const PARTS_PATH := "res://data/parts.json"
const TIERS_PATH := "res://data/tiers.json"
const COMPOUNDS_PATH := "res://data/tyre_compounds.json"

const _TAG := "Data"

## Part id -> part definition.
var parts: Dictionary = {}
## Ascending by min_elo.
var tiers: Array = []
## Compound id -> compound definition.
var compounds: Dictionary = {}

var load_errors: PackedStringArray = []


func _ready() -> void:
	load_errors = reload()
	if load_errors.is_empty():
		Log.info(_TAG, "Loaded %d parts, %d tiers, %d compounds" % [
			parts.size(), tiers.size(), compounds.size()
		])
		return
	for message: String in load_errors:
		Log.error(_TAG, message)


func reload() -> PackedStringArray:
	var errors: PackedStringArray = []

	var parts_data: Variant = read_json(PARTS_PATH)
	errors.append_array(_prefix(PARTS_PATH, validate_parts(parts_data)))
	if errors.is_empty():
		parts = index_by_id((parts_data as Dictionary)["parts"])

	var tiers_data: Variant = read_json(TIERS_PATH)
	var tier_errors := _prefix(TIERS_PATH, validate_tiers(tiers_data))
	errors.append_array(tier_errors)
	if tier_errors.is_empty():
		tiers = (tiers_data as Dictionary)["tiers"]

	var compound_data: Variant = read_json(COMPOUNDS_PATH)
	var compound_errors := _prefix(COMPOUNDS_PATH, validate_compounds(compound_data))
	errors.append_array(compound_errors)
	if compound_errors.is_empty():
		compounds = index_by_id((compound_data as Dictionary)["compounds"])

	return errors


func get_part(id: String) -> Dictionary:
	return parts.get(id, {})


func parts_for_slot(slot: String) -> Array:
	var matches: Array = []
	for part: Dictionary in parts.values():
		if part.get("slot", "") == slot:
			matches.append(part)
	return matches


func get_compound(id: String) -> Dictionary:
	return compounds.get(id, {})


func tier_for_elo(elo: int) -> Dictionary:
	return resolve_tier(elo, tiers)


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func index_by_id(entries: Array) -> Dictionary:
	var indexed: Dictionary = {}
	for entry: Dictionary in entries:
		indexed[entry["id"]] = entry
	return indexed


## Tiers are ordered ascending, so the last band whose threshold the rating
## clears is the answer. A rating below the lowest band still resolves to it,
## so a penalty cannot leave an account tierless. Returns {} only for an empty
## tier list.
static func resolve_tier(elo: int, tier_list: Array) -> Dictionary:
	if tier_list.is_empty():
		return {}
	var found: Dictionary = tier_list[0]
	for tier: Dictionary in tier_list:
		if elo < int(tier.get("min_elo", 0)):
			break
		found = tier
	return found


static func validate_parts(data: Variant) -> PackedStringArray:
	var errors := _validate_envelope(data, "parts")
	if not errors.is_empty():
		return errors

	var seen_ids: Dictionary = {}
	for entry: Variant in (data as Dictionary)["parts"]:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("part entry is not an object")
			continue
		var part := entry as Dictionary
		var id := str(part.get("id", ""))
		if id.is_empty():
			errors.append("part is missing 'id'")
			continue
		if seen_ids.has(id):
			errors.append("duplicate part id '%s'" % id)
		seen_ids[id] = true

		var slot := str(part.get("slot", ""))
		if not CarStats.is_slot(slot):
			errors.append("part '%s' has unknown slot '%s'" % [id, slot])
		if not CarStats.is_rarity(str(part.get("rarity", ""))):
			errors.append("part '%s' has unknown rarity '%s'" % [id, part.get("rarity", "")])

		errors.append_array(_validate_part_stats(id, part.get("stats")))
		if part.has("tuning"):
			errors.append_array(_validate_part_tuning(id, slot, part["tuning"]))

	return errors


static func validate_tiers(data: Variant) -> PackedStringArray:
	var errors := _validate_envelope(data, "tiers")
	if not errors.is_empty():
		return errors

	var tier_list: Array = (data as Dictionary)["tiers"]
	if tier_list.is_empty():
		errors.append("tier list is empty")
		return errors

	var seen_ids: Dictionary = {}
	var previous_min: int = -1
	for entry: Variant in tier_list:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("tier entry is not an object")
			continue
		var tier := entry as Dictionary
		var id := str(tier.get("id", ""))
		if id.is_empty():
			errors.append("tier is missing 'id'")
			continue
		if seen_ids.has(id):
			errors.append("duplicate tier id '%s'" % id)
		seen_ids[id] = true

		if not tier.has("min_elo"):
			errors.append("tier '%s' is missing 'min_elo'" % id)
			continue
		var min_elo := int(tier["min_elo"])
		if min_elo <= previous_min:
			errors.append("tier '%s' min_elo %d does not increase" % [id, min_elo])
		previous_min = min_elo

	# Without a band starting at zero, a new account's rating maps to no tier.
	if not tier_list.is_empty() and int((tier_list[0] as Dictionary).get("min_elo", -1)) != 0:
		errors.append("lowest tier must start at min_elo 0")

	return errors


static func validate_compounds(data: Variant) -> PackedStringArray:
	var errors := _validate_envelope(data, "compounds")
	if not errors.is_empty():
		return errors

	var seen_ids: Dictionary = {}
	for entry: Variant in (data as Dictionary)["compounds"]:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("compound entry is not an object")
			continue
		var compound := entry as Dictionary
		var id := str(compound.get("id", ""))
		if id.is_empty():
			errors.append("compound is missing 'id'")
			continue
		if seen_ids.has(id):
			errors.append("duplicate compound id '%s'" % id)
		seen_ids[id] = true

		for field: String in ["grip_multiplier", "wear_multiplier"]:
			if not compound.has(field):
				errors.append("compound '%s' is missing '%s'" % [id, field])
			elif float(compound[field]) <= 0.0:
				errors.append("compound '%s' has non-positive %s" % [id, field])

	return errors


static func _validate_envelope(data: Variant, list_key: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("file is missing or is not a JSON object")
		return errors
	var dict := data as Dictionary
	if int(dict.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
	if typeof(dict.get(list_key)) != TYPE_ARRAY:
		errors.append("missing '%s' array" % list_key)
	return errors


static func _validate_part_stats(id: String, stats: Variant) -> PackedStringArray:
	var errors: PackedStringArray = []
	if typeof(stats) != TYPE_DICTIONARY:
		errors.append("part '%s' is missing 'stats'" % id)
		return errors
	for stat: String in (stats as Dictionary):
		if not CarStats.is_stat(stat):
			errors.append("part '%s' has unknown stat '%s'" % [id, stat])
			continue
		var value := float((stats as Dictionary)[stat])
		if value < CarStats.RATING_MIN or value > CarStats.RATING_MAX:
			errors.append("part '%s' stat '%s' is out of 0-100 range" % [id, stat])
	return errors


static func _validate_part_tuning(id: String, slot: String, tuning: Variant) -> PackedStringArray:
	var errors: PackedStringArray = []
	if typeof(tuning) != TYPE_DICTIONARY:
		errors.append("part '%s' has non-object 'tuning'" % id)
		return errors

	var config := tuning as Dictionary
	var slider := str(config.get("slider", ""))
	if not CarStats.SETUP_SLIDERS.has(slider):
		errors.append("part '%s' has unknown slider '%s'" % [id, slider])
	elif CarStats.SETUP_SLIDERS[slider] != slot:
		errors.append("part '%s' in slot '%s' cannot own slider '%s'" % [id, slot, slider])

	var minimum := float(config.get("min", -1.0))
	var maximum := float(config.get("max", -1.0))
	if minimum < CarStats.RATING_MIN or maximum > CarStats.RATING_MAX:
		errors.append("part '%s' tuning range is outside 0-100" % id)
	if minimum >= maximum:
		errors.append("part '%s' tuning min is not below max" % id)

	return errors


static func _prefix(path: String, errors: PackedStringArray) -> PackedStringArray:
	var prefixed: PackedStringArray = []
	for message: String in errors:
		prefixed.append("%s: %s" % [path.get_file(), message])
	return prefixed
