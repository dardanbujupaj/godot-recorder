extends Object

signal update_progress


# Called when the node enters the scene tree for the first time.
func _init() -> void:
	pass # Replace with function body.


func write(basename: String, frames: Array, color_type: int, framerate: float):
	for i in range(frames.size()):
		(frames[i] as Image).save_png("%s_%04d.%s" % [basename, i, "png"])
		emit_signal("update_progress", {
			"step": "Writing frames",
			"value": i,
			"max_value": frames.size()
		})
