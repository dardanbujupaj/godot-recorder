extends Node

export var framerate = 30

var recording = false
var recorded_images = []
var last_frame: int

var thread: Thread
var kill_thread = false
var image_semaphore = Semaphore.new()
var preprocess_counter = 0
var preprocess_gate = Mutex.new()

func _exit_tree():
	if thread != null:
		kill_thread = true
		image_semaphore.post()
		thread.wait_to_finish()



func _process(delta):
	if recording and OS.get_ticks_usec() >= (last_frame + (1000000 / framerate)):
		last_frame = OS.get_ticks_usec()
		var image = get_viewport().get_texture().get_data()
		recorded_images.append(image)
		
		image_semaphore.post()


func _unhandled_input(event):
	if Input.is_action_just_pressed("start_recording") and !recording:
		start_recording()
		
	elif Input.is_action_just_pressed("stop_recording") and recording:
		stop_recording()


var start = 0
func start_recording():
	print("start recording")
	start = OS.get_ticks_usec()
	thread = Thread.new()
	preprocess_counter = 0
	thread.start(self, "_preprocess_image")
	
	recorded_images = []
	recording = true


func stop_recording():
	print("stop recording")
	yield(get_tree().create_timer(1), "timeout")
	print("%dus" % (OS.get_ticks_usec() - start))
	
	recording = false
	
	# post to semaphore a last time to start writing png
	image_semaphore.post()
	
	
	
	#thread.start($ApngConverter, "write_png", recorded_images)



func _preprocess_image(userdata):
	while true:
		image_semaphore.wait()
		if kill_thread:
			return
		
		if !recording and preprocess_counter >= recorded_images.size():
			# yield(get_tree().create_timer(1), "timeout")
			print ("%d frames" % recorded_images.size())
			print(preprocess_counter)
			
			print(framerate)
			print("should be %dus" % (1000000 / framerate * recorded_images.size()))
			$ApngConverter.write_png(recorded_images, framerate)
			return
		
		var image = recorded_images[preprocess_counter]
		# image.shrink_x2()
		image.convert(Image.FORMAT_RGBA8)
		image.flip_y()
		preprocess_counter += 1
		
		
		




func _on_ApngConverter_update_progress(progress):
	print(progress)
