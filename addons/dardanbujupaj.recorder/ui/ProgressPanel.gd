extends PanelContainer


func update_progress(progress: Dictionary):
	$VBoxContainer/StepLabel.text = progress["step"]
	$VBoxContainer/Progress.value = float(progress["value"])
	$VBoxContainer/Progress.max_value = float(progress["max_value"])
