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
const TRACKS_DIR := "res://data/tracks"

const TRACK_TYPES: Array[String] = [
	"high_speed",
	"street",
	"technical",
	"elevation",
	"mixed",
]

const MIN_TRACK_SEGMENTS: int = 3
const MAX_CORNER_ANGLE_DEG: float = 180.0
const MAX_BANKING_DEG: float = 15.0
const FULL_TURN_DEG: float = 360.0
const TRACK_CLOSURE_TOLERANCE_DEG: float = 5.0
const MAX_CLOSURE_GAP_M: float = 2.0

const _TAG := "Data"

## Part id -> part definition.
var parts: Dictionary = {}
## Ascending by min_elo.
var tiers: Array = []
## Compound id -> compound definition.
var compounds: Dictionary = {}
## Track id -> track definition.
var tracks: Dictionary = {}

var load_errors: PackedStringArray = []


func _ready() -> void:
	load_errors = reload()
	if load_errors.is_empty():
		Log.info(_TAG, "Loaded %d parts, %d tiers, %d compounds, %d tracks" % [
			parts.size(), tiers.size(), compounds.size(), tracks.size()
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

	tracks = {}
	for path: String in track_paths():
		var track_data: Variant = read_json(path)
		var track_errors := _prefix(path, validate_track(track_data))
		if not track_errors.is_empty():
			errors.append_array(track_errors)
			continue
		var track := track_data as Dictionary
		var track_id := str(track["id"])
		if tracks.has(track_id):
			errors.append("%s: duplicate track id '%s'" % [path.get_file(), track_id])
			continue
		tracks[track_id] = track

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


func get_track(id: String) -> Dictionary:
	return tracks.get(id, {})


func tier_for_elo(elo: int) -> Dictionary:
	return resolve_tier(elo, tiers)


static func track_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(TRACKS_DIR):
		var source := file_name.trim_suffix(".remap")
		if source.ends_with(".json"):
			paths.append("%s/%s" % [TRACKS_DIR, source])
	paths.sort()
	return paths


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


static func validate_track(data: Variant) -> PackedStringArray:
	var errors: PackedStringArray = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("file is missing or is not a JSON object")
		return errors

	var track := data as Dictionary
	if int(track.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
	if str(track.get("id", "")).is_empty():
		errors.append("track is missing 'id'")
	if str(track.get("name", "")).is_empty():
		errors.append("track is missing 'name'")
	if not TRACK_TYPES.has(str(track.get("type", ""))):
		errors.append("unknown track type '%s'" % track.get("type", ""))
	if float(track.get("width_m", 0.0)) <= 0.0:
		errors.append("width_m must be positive")
	if int(track.get("race_laps", 0)) < 1:
		errors.append("race_laps must be at least 1")
	if int(track.get("sector_count", 0)) < 1:
		errors.append("sector_count must be at least 1")

	if typeof(track.get("segments")) != TYPE_ARRAY:
		errors.append("missing 'segments' array")
		return errors

	var segments: Array = track["segments"]
	if segments.size() < MIN_TRACK_SEGMENTS:
		errors.append("track needs at least %d segments" % MIN_TRACK_SEGMENTS)
	for index: int in segments.size():
		errors.append_array(_validate_segment(index, segments[index]))
	errors.append_array(_validate_pit(track.get("pit"), segments.size()))

	if not errors.is_empty():
		return errors

	if not track_closes(track):
		errors.append(
			"corner angles total %.1f degrees, so the centreline does not close"
			% track_turn_degrees(track)
		)
		return errors

	var gap := TrackLayout.from_track(track).closure_gap_m()
	if gap > MAX_CLOSURE_GAP_M:
		errors.append("centreline ends %.1f m away from the start line" % gap)

	return errors


static func track_turn_degrees(track: Dictionary) -> float:
	var total: float = 0.0
	for entry: Variant in track.get("segments", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var segment := entry as Dictionary
		if str(segment.get("kind", "")) == "corner":
			total += float(segment.get("angle_deg", 0.0))
	return total


static func track_closes(track: Dictionary) -> bool:
	return absf(absf(track_turn_degrees(track)) - FULL_TURN_DEG) <= TRACK_CLOSURE_TOLERANCE_DEG


static func track_length_m(track: Dictionary) -> float:
	var total: float = 0.0
	for entry: Variant in track.get("segments", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var segment := entry as Dictionary
		match str(segment.get("kind", "")):
			"straight", "chicane":
				total += float(segment.get("length_m", 0.0))
			"corner":
				var arc := absf(deg_to_rad(float(segment.get("angle_deg", 0.0))))
				total += float(segment.get("radius_m", 0.0)) * arc
	return total


static func _validate_segment(index: int, entry: Variant) -> PackedStringArray:
	var errors: PackedStringArray = []
	if typeof(entry) != TYPE_DICTIONARY:
		errors.append("segment %d is not an object" % index)
		return errors

	var segment := entry as Dictionary
	var kind := str(segment.get("kind", ""))
	match kind:
		"straight":
			if float(segment.get("length_m", 0.0)) <= 0.0:
				errors.append("segment %d straight needs a positive length_m" % index)
		"corner":
			var angle := float(segment.get("angle_deg", 0.0))
			if is_zero_approx(angle) or absf(angle) > MAX_CORNER_ANGLE_DEG:
				errors.append(
					"segment %d corner angle_deg must be non-zero and within %d degrees"
					% [index, int(MAX_CORNER_ANGLE_DEG)]
				)
			if float(segment.get("radius_m", 0.0)) <= 0.0:
				errors.append("segment %d corner needs a positive radius_m" % index)
			if absf(float(segment.get("banking_deg", 0.0))) > MAX_BANKING_DEG:
				errors.append(
					"segment %d banking_deg exceeds %d degrees"
					% [index, int(MAX_BANKING_DEG)]
				)
		"chicane":
			if float(segment.get("length_m", 0.0)) <= 0.0:
				errors.append("segment %d chicane needs a positive length_m" % index)
			if is_zero_approx(float(segment.get("offset_m", 0.0))):
				errors.append("segment %d chicane needs a non-zero offset_m" % index)
		_:
			errors.append("segment %d has unknown kind '%s'" % [index, kind])

	return errors


static func _validate_pit(data: Variant, segment_count: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("missing 'pit' object")
		return errors

	var pit := data as Dictionary
	for field: String in ["entry_segment", "exit_segment"]:
		if not pit.has(field):
			errors.append("pit is missing '%s'" % field)
			continue
		var index := int(pit[field])
		if index < 0 or index >= segment_count:
			errors.append("pit %s %d is outside the segment list" % [field, index])
	if pit.has("entry_segment") and int(pit["entry_segment"]) == int(pit.get("exit_segment", -1)):
		errors.append("pit entry and exit cannot be the same segment")
	if float(pit.get("lane_speed_kph", 0.0)) <= 0.0:
		errors.append("pit lane_speed_kph must be positive")

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
