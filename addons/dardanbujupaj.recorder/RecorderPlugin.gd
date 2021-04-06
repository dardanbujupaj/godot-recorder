tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("Recorder", "Node", preload("./Recorder.gd"), preload("./Recorder.svg"))


func _exit_tree() -> void:
	remove_custom_type("Recorder")
