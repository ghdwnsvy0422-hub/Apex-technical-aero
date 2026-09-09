extends GutTest

const Registry := preload("res://core/data_registry.gd")

const SHIPPED_TRACK := "res://data/tracks/aurora_speedway.json"


func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func test_where_the_orphans_come_from() -> void:
	var base := _orphans()
	var timer := LapTimer.create(300.0, 3)
	timer.update(0.0, 0.0)
	timer.update(150.0, 1.0)
	gut.p("orphans: lap timer %d" % [_orphans() - base])

	base = _orphans()
	watch_signals(timer)
	timer.update(299.0, 2.0)
	gut.p("orphans: watch_signals %d" % [_orphans() - base])

	base = _orphans()
	var track := Registry.read_json(SHIPPED_TRACK) as Dictionary
	gut.p("orphans: read_json %d" % [_orphans() - base])

	base = _orphans()
	var curve := TrackCompiler.curve_from(track)
	gut.p("orphans: curve_from %d" % [_orphans() - base])

	base = _orphans()
	var recovered := curve.get_closest_offset(curve.sample_baked(100.0))
	gut.p("orphans: curve sampling %d (offset %.1f)" % [_orphans() - base, recovered])

	base = _orphans()
	var node := TrackCompiler.build(track)
	node.free()
	gut.p("orphans: build and free %d" % [_orphans() - base])

	base = _orphans()
	var layout := TrackLayout.from_track(track)
	gut.p("orphans: layout %d (%d points)" % [_orphans() - base, layout.positions.size()])

	assert_gt(_orphans(), -1, "orphan probe ran")
