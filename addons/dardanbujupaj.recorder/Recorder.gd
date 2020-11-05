tool
extends Node


enum ColorType {
	GREYSCALE = 0
	TRUECOLOR = 2
	# INDEXEDCOLOR = 3
	GREYSCALE_ALPHA = 4
	TRUECOLOR_ALPHA = 6
}


export(float) var framerate = 30.0
export(ColorType) var color_type = ColorType.TRUECOLOR


var recording = false
var recorded_images = []

var thread: Thread
var kill_thread = false
var image_semaphore = Semaphore.new()
var preprocess_counter = 0

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
func _unhandled_input(event):
	if Input.is_action_just_pressed("start_recording") and !recording:
		start_recording()
		
	elif Input.is_action_just_pressed("stop_recording") and recording:
		stop_recording()


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



func _preprocess_image(userdata):
	while true:
		image_semaphore.wait()
		if kill_thread:
			return
		
		if !recording and preprocess_counter >= recorded_images.size():
			# yield(get_tree().create_timer(1), "timeout")
			print ("recorded %d frames" % recorded_images.size())
			
			$ApngConverter.write_png(recorded_images, color_type, framerate)
			$CanvasLayer/PanelContainer.hide()
			thread.wait_to_finish()
			return
		
		var image = recorded_images[preprocess_counter]
		# image.shrink_x2()
		image.convert(_get_image_format())
		image.flip_y()
		preprocess_counter += 1
		_on_progress_update({
			"step": "Preprocess Images",
			"value": preprocess_counter,
			"max_value": recorded_images.size()
		})
		
		

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
