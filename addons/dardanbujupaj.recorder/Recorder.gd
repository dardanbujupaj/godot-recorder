extends Node

const FRAMERATE = 30

var recording = false
var recorded_images = []
var last_frame: int

var thread: Thread

func _exit_tree():
	if thread != null:
		thread.wait_to_finish()


func _process(delta):
	if recording and OS.get_ticks_msec() > last_frame + 1000 / FRAMERATE:
		last_frame = OS.get_ticks_msec()
		recorded_images.append(get_viewport().get_texture().get_data())


func _unhandled_input(event):
	if Input.is_action_just_pressed("start_recording") and !recording:
		start_recording()
		
	elif Input.is_action_just_pressed("stop_recording") and recording:
		stop_recording()


func start_recording():
	recorded_images = []
	recording = true


func stop_recording():
	recording = false
	print ("%d frames" % recorded_images.size())
	
	$ApngConverter.write_png(recorded_images, FRAMERATE)
	#thread = Thread.new()
	#thread.start($ApngConverter, "write_png", recorded_images)
	


