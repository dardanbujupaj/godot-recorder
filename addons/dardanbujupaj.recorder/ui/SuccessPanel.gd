extends PanelContainer
signal show_file_manager


func show() -> void:
	$Timer.start(5)
	.show()


func _on_Timer_timeout() -> void:
	hide()


func _on_ShowFileManager_pressed() -> void:
	emit_signal("show_file_manager")
