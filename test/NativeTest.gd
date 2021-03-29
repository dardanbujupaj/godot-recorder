extends Control


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"
# load the Simple library
onready var exporter = preload("res://exporter/bin/exporter.gdns").new()



func _on_Test_pressed() -> void:
	var image = get_viewport().get_texture().get_data()
	print(image.get_format())
	var result = exporter.export_frames([image], "test.png")
	if result != 0:
		print("Export failed: %d" % result)
