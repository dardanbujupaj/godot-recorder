tool
extends Node

# use R as default trigger for start/stop recording
static func get_default_trigger():
	var event = InputEventKey.new()
	event.scancode = KEY_R
	return event


enum ColorType {
	GREYSCALE = 0
	TRUECOLOR = 2
	# INDEXEDCOLOR = 3
	GREYSCALE_ALPHA = 4
	TRUECOLOR_ALPHA = 6
}

enum Format {
	APNG
	PNG_SEQUENCE
	# GIF
}


export(float) var framerate: float = 30.0
export(ColorType) var color_type: int = ColorType.TRUECOLOR
# export(Rect2) var crop: Rect2 = Rect2()
export(float, EXP, 0.1, 10, 0.1) var scale: float = 1.0
export(Format) var format: int = Format.APNG

export(InputEvent) var trigger: InputEvent = get_default_trigger()
export(String) var export_path: String = "user://"


var recording = false
var recorded_images = []

var thread: Thread
var kill_thread = false
var image_semaphore = Semaphore.new()
var preprocess_counter = 0


var converters = {
	Format.APNG: preload("ApngConverter.gd").new(),
	Format.PNG_SEQUENCE: preload("PngSequenceConverter.gd").new(),
}


func _exit_tree():
	if thread != null:
		# tell thread to abort processing
		kill_thread = true
		# notify thread to proceed
		image_semaphore.post()
		# wait for thread to finish
		thread.wait_to_finish()


var frame_offset: float = 0.0

func _process(delta):
	frame_offset += delta
	
	if recording and frame_offset >= 1.0 / framerate:
		frame_offset -= 1.0 / framerate
		
		# get frame image
		var image = get_viewport().get_texture().get_data()
		recorded_images.append(image)
		
		# notify thread to preprocess image
		image_semaphore.post()


# listen for user input to start/stop recording
func _unhandled_input(event: InputEvent):
	if event.shortcut_match(trigger) and event.is_pressed() and not event.is_echo():
		if recording:
			stop_recording()
		else:
			start_recording()


var start = 0
func start_recording():
	if thread != null and thread.is_active():
		print("recording already in progress...")
		return
	
	frame_offset = 1.0 / framerate
	print("start recording")
	start = OS.get_ticks_usec()
	thread = Thread.new()
	preprocess_counter = 0
	thread.start(self, "_preprocess_image")
	
	recorded_images = []
	recording = true


func stop_recording():
	print("stop recording")
	print("%dus" % (OS.get_ticks_usec() - start))
	print("should be %dus" % (1000000 / framerate * recorded_images.size()))
	
	$CanvasLayer/PanelContainer.show()
	_on_progress_update({
			"step": "Preprocess Images",
			"value": preprocess_counter,
			"max_value": recorded_images.size()
	})
	recording = false
	
	# post to semaphore a last time to start writing png
	image_semaphore.post()



func _preprocess_image(userdata: Object) -> void:
	while true:
		image_semaphore.wait()
		if kill_thread:
			return
		
		if !recording and preprocess_counter >= recorded_images.size():
			# yield(get_tree().create_timer(1), "timeout")
			print ("recorded %d frames" % recorded_images.size())
			
			var basename = get_file_basename()
			
			var converter = converters[format]
			converter.connect("update_progress", self, "_on_progress_update")
			
			converter.write(basename, recorded_images, color_type, framerate)
			
			
			# hide progress and show link to folder
			$CanvasLayer/PanelContainer.hide()
			$SuccessPanelTimer.start()
			$CanvasLayer/SuccessPanel.show()
			
			# wait for thread to finish
			thread.wait_to_finish()
			return
		
		var image: Image = recorded_images[preprocess_counter]
		image.resize(image.get_width() * scale, image.get_height() * scale)
		image.convert(_get_image_format())
		image.flip_y()
		
		preprocess_counter += 1
		_on_progress_update({
			"step": "Preprocess Images",
			"value": preprocess_counter,
			"max_value": recorded_images.size()
		})


func get_file_basename():
	
	var prefix = "recording"
	
	var dt = OS.get_datetime()
	var timestamp = ("%04d%02d%02d%02d%02d%02d" %
					 [dt["year"], dt["month"], dt["day"], 
					 dt["hour"], dt["minute"], dt["second"]])
	
	return export_path.plus_file("%s_%s" % [prefix, timestamp])


func _get_image_format():
	match color_type:
		ColorType.GREYSCALE:
			return Image.FORMAT_L8
		ColorType.GREYSCALE_ALPHA:
			return Image.FORMAT_LA8
		ColorType.TRUECOLOR:
			return Image.FORMAT_RGB8
		ColorType.TRUECOLOR_ALPHA:
			return Image.FORMAT_RGBA8


func _on_progress_update(progress: Dictionary):
	$CanvasLayer/PanelContainer/VBoxContainer/Step.text = progress["step"]
	$CanvasLayer/PanelContainer/VBoxContainer/ProgressBar.value = progress["value"]
	$CanvasLayer/PanelContainer/VBoxContainer/ProgressBar.max_value = progress["max_value"]


func _on_SuccessPanelTimer_timeout() -> void:
	$CanvasLayer/SuccessPanel.hide()


func _on_ShowFileManager_pressed() -> void:
	var dest = export_path
	dest = dest.replace("user://", OS.get_user_data_dir())
	
	OS.shell_open(str("file://", dest))
