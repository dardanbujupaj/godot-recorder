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
	GIF
}


export(float) var framerate: float = 30.0 setget _set_framerate
export(ColorType) var color_type: int = ColorType.TRUECOLOR_ALPHA
# export(Rect2) var crop: Rect2 = Rect2()
export(float, EXP, 0.1, 10, 0.1) var scale: float = 1.0
export(Format) var format: int = Format.GIF setget _set_format

export(InputEvent) var custom_trigger: InputEvent = null
export(String) var export_path: String = "user://"


var recording = false
var recorded_images = []

var thread: Thread
var kill_thread = false
var image_semaphore = Semaphore.new()
var preprocess_counter = 0

var canvas_layer = CanvasLayer.new()
var progress_panel = preload("./ui/ProgressPanel.tscn").instance()
var success_panel = preload("./ui/SuccessPanel.tscn").instance()



var converters = {
	Format.APNG: preload("ApngConverter.gd"),
	Format.PNG_SEQUENCE: preload("PngSequenceConverter.gd"),
	Format.GIF: preload("gif-exporter/bin/GifExporter.gdns")
}


func _ready() -> void:
	# add canvas layer to add UI elements
	canvas_layer.add_child(progress_panel)
	
	success_panel.connect("show_file_manager", self, "_on_ShowFileManager_pressed")
	canvas_layer.add_child(success_panel)
	add_child(canvas_layer)
	


func _exit_tree() -> void:
	if thread != null:
		# tell thread to abort processing
		kill_thread = true
		# notify thread to proceed
		image_semaphore.post()
		# wait for thread to finish
		thread.wait_to_finish()


var frame_offset: float = 0.0

func _process(delta: float) -> void:
	frame_offset += delta
	
	if recording and frame_offset >= 1.0 / framerate:
		frame_offset -= 1.0 / framerate
		
		# get frame image
		var image = get_viewport().get_texture().get_data()
		recorded_images.append(image)
		
		# notify thread to preprocess image
		image_semaphore.post()


# listen for user input to start/stop recording
func _unhandled_input(event: InputEvent) -> void:
	var trigger = custom_trigger
	if trigger == null:
		trigger = get_default_trigger()
	
	if trigger.shortcut_match(event) and event.is_pressed() and not event.is_echo():
		if recording:
			stop_recording()
		else:
			start_recording()


func _get_configuration_warning() -> String:
	if format == Format.GIF:
		if framerate > 50:
			return "Max framerate for GIF is 50"
	return ""


var start = 0
func start_recording() -> void:
	if thread != null and thread.is_active():
		print("recording already in progress...")
		return
	
	frame_offset = 1.0 / framerate
	print("start recording")
	start = OS.get_ticks_msec()
	thread = Thread.new()
	preprocess_counter = 0
	thread.start(self, "_preprocess_image")
	
	recorded_images = []
	recording = true


func stop_recording() -> void:
	print("recorded %dms" % (OS.get_ticks_msec() - start))
	
	progress_panel.show()
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
			print ("recorded %d frames" % recorded_images.size())
			
			var basename = get_file_basename()
			
			var converter = converters[format].new()
			converter.connect("update_progress", self, "_on_progress_update")
			
			converter.write(basename, recorded_images, color_type, framerate)
			
			
			# hide progress and show link to folder
			progress_panel.hide()
			success_panel.show()
			
			# wait for finish in main thread
			thread.call_deferred("wait_to_finish")
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


# Get filename for new Recording
# Omits fileextension, which is added in the exporter
func get_file_basename() -> String:
	var prefix = "recording"
	
	var dt = OS.get_datetime()
	var timestamp = ("%04d%02d%02d%02d%02d%02d" %
					 [dt["year"], dt["month"], dt["day"], 
					 dt["hour"], dt["minute"], dt["second"]])
					
	var basename = export_path.replace("user://", OS.get_user_data_dir() + "/")
	# Create dir if it doesn't exist yet
	var dir = Directory.new()
	dir.make_dir_recursive(export_path)
	
	return basename.plus_file("%s_%s" % [prefix, timestamp])


func _set_framerate(new_framerate: float) -> void:
	framerate = new_framerate
	update_configuration_warning()
	

func _set_format(new_format: int) -> void:
	format = new_format
	update_configuration_warning()

func _get_image_format() -> int:
	match color_type:
		ColorType.GREYSCALE:
			return Image.FORMAT_L8
		ColorType.GREYSCALE_ALPHA:
			return Image.FORMAT_LA8
		ColorType.TRUECOLOR:
			return Image.FORMAT_RGB8
		ColorType.TRUECOLOR_ALPHA:
			return Image.FORMAT_RGBA8
		_:
			return Image.FORMAT_RGBA8


func _on_progress_update(progress: Dictionary) -> void:
	progress_panel.update_progress(progress)


func _on_SuccessPanelTimer_timeout() -> void:
	success_panel.hide()


func _on_ShowFileManager_pressed() -> void:
	print("open dir")
	var path = export_path.replace("user://", OS.get_user_data_dir() + "/")
	OS.shell_open(str("file://", path))
