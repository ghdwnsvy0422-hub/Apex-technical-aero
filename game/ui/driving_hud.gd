class_name DrivingHud
extends Control
## Minimal driving readout: speed, gear, engine speed.
##
## The full race HUD (position, gaps, tyres, damage) arrives in Phase 2.6; this
## exists so the car's state is visible while the handling is being tuned.

const REDLINE_COLOUR := Color(0.92, 0.22, 0.18)
const BAR_COLOUR := Color(0.35, 0.78, 0.98)
const PANEL_COLOUR := Color(0.05, 0.06, 0.09, 0.72)

var car: CarBody

var _speed_label: Label
var _gear_label: Label
var _rpm_fill: ColorRect
var _rpm_width: float = 240.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _process(_delta: float) -> void:
	# A Control inside a CanvasLayer is not resized by the viewport, so its
	# rect stays empty and every anchored child lands off-screen.
	size = get_viewport_rect().size
	if car == null:
		return

	_speed_label.text = "%d" % roundi(car.speed_kph())
	_gear_label.text = "N" if car.gear < 0 else str(car.gear + 1)

	var redline := car.setup.engine_max_rpm
	var fraction := clampf(car.engine_rpm / redline, 0.0, 1.0)
	_rpm_fill.size.x = _rpm_width * fraction
	_rpm_fill.color = REDLINE_COLOUR if fraction > 0.92 else BAR_COLOUR


func _build() -> void:
	var panel := ColorRect.new()
	panel.color = PANEL_COLOUR
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -330.0
	panel.offset_top = -162.0
	panel.offset_right = -30.0
	panel.offset_bottom = -30.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_speed_label = _label(72, Color.WHITE)
	_speed_label.position = Vector2(18.0, 6.0)
	_speed_label.size = Vector2(170.0, 84.0)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(_speed_label)

	var unit := _label(18, Color(0.72, 0.76, 0.82))
	unit.text = "KM/H"
	unit.position = Vector2(196.0, 52.0)
	panel.add_child(unit)

	_gear_label = _label(44, Color(0.98, 0.78, 0.25))
	_gear_label.position = Vector2(200.0, 2.0)
	panel.add_child(_gear_label)

	var track := ColorRect.new()
	track.color = Color(1.0, 1.0, 1.0, 0.12)
	track.position = Vector2(18.0, 100.0)
	track.size = Vector2(_rpm_width, 14.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(track)

	_rpm_fill = ColorRect.new()
	_rpm_fill.color = BAR_COLOUR
	_rpm_fill.size = Vector2(0.0, 14.0)
	_rpm_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_rpm_fill)


func _label(size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
