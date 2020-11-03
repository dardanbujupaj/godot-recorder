extends Node

export var framerate = 30

var recording = false
var recorded_images = []
var last_frame: int

var thread: Thread
var kill_thread = false
var image_semaphore = Semaphore.new()
var preprocess_counter = 0

func _exit_tree():
	if thread != null:
		kill_thread = true
		thread.wait_to_finish()



func _process(delta):
	if recording and OS.get_ticks_msec() > last_frame + 1000 / framerate:
		last_frame = OS.get_ticks_msec()
		var image = get_viewport().get_texture().get_data()
		recorded_images.append(image)
		
		image_semaphore.post()


func _unhandled_input(event):
	if Input.is_action_just_pressed("start_recording") and !recording:
		start_recording()
		
	elif Input.is_action_just_pressed("stop_recording") and recording:
		stop_recording()


func start_recording():
	thread = Thread.new()
	thread.start(self, "_preprocess_image")
	
	recorded_images = []
	recording = true


func stop_recording():
	recording = false
	print ("%d frames" % recorded_images.size())
	
	$ApngConverter.write_png(recorded_images, framerate)
	#thread.start($ApngConverter, "write_png", recorded_images)
	

func _preprocess_image(userdata):
	while true:
		image_semaphore.wait()
		if kill_thread:
			return
		
		var image = recorded_images[preprocess_counter]
		image.convert(Image.FORMAT_RGBA8)
		image.flip_y()
		


