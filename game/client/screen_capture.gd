extends Node
## Saves a screenshot once the simulation has run for a given time, then quits.
##
## Vibe coding has nobody watching the window, so this is how a visual change is
## actually verified rather than assumed. The wait is measured in simulation
## time, not frames: software rendering is slow enough that Godot caps how many
## physics steps it runs per frame, so a frame count would capture a car that
## has barely moved.

const TAG: String = "Capture"

var output_path: String = "capture.png"
var delay_seconds: float = 20.0

var _elapsed: float = 0.0


func _physics_process(delta: float) -> void:
	_elapsed += delta


func _ready() -> void:
	while _elapsed < delay_seconds:
		await get_tree().process_frame

	# The viewport texture only holds this frame's image once drawing is done.
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(output_path)
	if result != OK:
		Log.error(TAG, "Failed to write %s (error %d)" % [output_path, result])
		get_tree().quit(1)
		return

	Log.info(TAG, "Wrote %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])
	get_tree().quit(0)
