extends Control


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"
# load the Simple library
onready var exporter = preload("res://exporter/bin/exporter.gdns").new()



func _on_Test_pressed() -> void:
	print(exporter.get_data())
