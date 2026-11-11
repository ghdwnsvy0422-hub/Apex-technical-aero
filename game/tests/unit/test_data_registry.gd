extends GutTest
## Content ships as JSON, so a malformed season file must fail loudly at boot
## rather than producing a quietly mis-specced car. These tests pin both the
## validation rules and the data currently in the repo.

const Registry := preload("res://core/data_registry.gd")


func _minimal_part(overrides: Dictionary = {}) -> Dictionary:
	var part: Dictionary = {
		"id": "test_part",
		"slot": "engine",
		"rarity": "common",
		"stats": {"top_speed": 30},
	}
	part.merge(overrides, true)
	return part


func _envelope(list_key: String, entries: Array) -> Dictionary:
	return {"schema_version": Registry.SCHEMA_VERSION, list_key: entries}


# --- shipped content -------------------------------------------------------

func test_shipped_parts_are_valid() -> void:
	var errors: PackedStringArray = Registry.validate_parts(
		Registry.read_json(Registry.PARTS_PATH)
	)
	assert_eq(errors, PackedStringArray(), "parts.json should validate clean")


func test_shipped_tiers_are_valid() -> void:
	var errors: PackedStringArray = Registry.validate_tiers(
		Registry.read_json(Registry.TIERS_PATH)
	)
	assert_eq(errors, PackedStringArray(), "tiers.json should validate clean")


func test_shipped_compounds_are_valid() -> void:
	var errors: PackedStringArray = Registry.validate_compounds(
		Registry.read_json(Registry.COMPOUNDS_PATH)
	)
	assert_eq(errors, PackedStringArray(), "tyre_compounds.json should validate clean")


func test_every_slot_has_at_least_one_part() -> void:
	var data: Dictionary = Registry.read_json(Registry.PARTS_PATH)
	var covered: Dictionary = {}
	for part: Dictionary in data["parts"]:
		covered[part["slot"]] = true
	for slot: String in CarStats.SLOTS:
		assert_true(covered.has(slot), "no part fits slot '%s'" % slot)


# --- envelope --------------------------------------------------------------

func test_missing_file_is_reported() -> void:
	assert_false(Registry.validate_parts(null).is_empty())


func test_wrong_schema_version_is_rejected() -> void:
	var data: Dictionary = {"schema_version": 99, "parts": []}
	assert_false(Registry.validate_parts(data).is_empty())


# --- parts -----------------------------------------------------------------

func test_valid_part_passes() -> void:
	var errors: PackedStringArray = Registry.validate_parts(
		_envelope("parts", [_minimal_part()])
	)
	assert_eq(errors, PackedStringArray())


func test_duplicate_part_id_is_rejected() -> void:
	var errors: PackedStringArray = Registry.validate_parts(
		_envelope("parts", [_minimal_part(), _minimal_part()])
	)
	assert_false(errors.is_empty())


func test_unknown_slot_is_rejected() -> void:
	var errors: PackedStringArray = Registry.validate_parts(
		_envelope("parts", [_minimal_part({"slot": "spoiler"})])
	)
	assert_false(errors.is_empty())


func test_unknown_stat_is_rejected() -> void:
	var errors: PackedStringArray = Registry.validate_parts(
		_envelope("parts", [_minimal_part({"stats": {"vibes": 50}})])
	)
	assert_false(errors.is_empty())


func test_out_of_range_stat_is_rejected() -> void:
	var errors: PackedStringArray = Registry.validate_parts(
		_envelope("parts", [_minimal_part({"stats": {"top_speed": 140}})])
	)
	assert_false(errors.is_empty())


func test_slider_owned_by_another_slot_is_rejected() -> void:
	var part: Dictionary = _minimal_part({
		"slot": "engine",
		"tuning": {"slider": "brake_balance", "min": 40, "max": 60},
	})
	assert_false(Registry.validate_parts(_envelope("parts", [part])).is_empty())


func test_inverted_tuning_range_is_rejected() -> void:
	var part: Dictionary = _minimal_part({
		"slot": "brakes",
		"tuning": {"slider": "brake_balance", "min": 70, "max": 30},
	})
	assert_false(Registry.validate_parts(_envelope("parts", [part])).is_empty())


func test_higher_rarity_never_raises_raw_stats() -> void:
	# PRD 26: rarity buys tuning freedom, not raw performance. Two parts in the
	# same slot with the same name family must differ only in tuning span.
	var data: Dictionary = Registry.read_json(Registry.PARTS_PATH)
	var by_slot: Dictionary = {}
	for part: Dictionary in data["parts"]:
		var slot: String = part["slot"]
		if not by_slot.has(slot):
			by_slot[slot] = []
		(by_slot[slot] as Array).append(part)

	for slot: String in by_slot:
		var group: Array = by_slot[slot]
		if group.size() < 2:
			continue
		var reference: Dictionary = (group[0] as Dictionary)["stats"]
		for part: Dictionary in group:
			assert_eq(
				part["stats"], reference,
				"parts in slot '%s' differ in raw stats across rarities" % slot
			)


# --- tiers -----------------------------------------------------------------

func test_tiers_must_ascend() -> void:
	var tiers: Array = [
		{"id": "a", "min_elo": 0},
		{"id": "b", "min_elo": 0},
	]
	assert_false(Registry.validate_tiers(_envelope("tiers", tiers)).is_empty())


func test_tiers_must_start_at_zero() -> void:
	var tiers: Array = [{"id": "a", "min_elo": 500}]
	assert_false(Registry.validate_tiers(_envelope("tiers", tiers)).is_empty())


func test_resolve_tier_picks_band_containing_rating() -> void:
	var tiers: Array = Registry.read_json(Registry.TIERS_PATH)["tiers"]
	assert_eq(Registry.resolve_tier(0, tiers)["id"], "bronze")
	assert_eq(Registry.resolve_tier(999, tiers)["id"], "bronze")
	assert_eq(Registry.resolve_tier(1000, tiers)["id"], "silver")
	assert_eq(Registry.resolve_tier(1428, tiers)["id"], "platinum")
	assert_eq(Registry.resolve_tier(5000, tiers)["id"], "grand_champion")


func test_rating_below_lowest_band_still_resolves() -> void:
	var tiers: Array = Registry.read_json(Registry.TIERS_PATH)["tiers"]
	assert_eq(Registry.resolve_tier(-200, tiers)["id"], "bronze")


func test_resolve_tier_on_empty_list_is_empty() -> void:
	assert_eq(Registry.resolve_tier(1500, []), {})


# --- tyre compounds --------------------------------------------------------

func test_non_positive_multiplier_is_rejected() -> void:
	var compounds: Array = [{
		"id": "broken",
		"grip_multiplier": 0.0,
		"wear_multiplier": 1.0,
	}]
	assert_false(Registry.validate_compounds(_envelope("compounds", compounds)).is_empty())


func test_softer_compound_grips_more_and_wears_faster() -> void:
	var compounds: Dictionary = Registry.index_by_id(
		Registry.read_json(Registry.COMPOUNDS_PATH)["compounds"]
	)
	var soft: Dictionary = compounds["soft"]
	var hard: Dictionary = compounds["hard"]
	assert_gt(float(soft["grip_multiplier"]), float(hard["grip_multiplier"]))
	assert_gt(float(soft["wear_multiplier"]), float(hard["wear_multiplier"]))
