extends Node
## Saves a screenshot after a fixed number of frames, then quits.
##
## Vibe coding has nobody watching the window, so this is how a visual change is
## actually verified rather than assumed. Frames are counted rather than
## seconds waited so a slow software renderer still produces the same shot.

const TAG: String = "Capture"

var output_path: String = "capture.png"
var delay_frames: int = 240


func _ready() -> void:
	for _frame: int in delay_frames:
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
