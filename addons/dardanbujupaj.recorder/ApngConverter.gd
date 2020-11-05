extends Node

signal update_progress

const PNG_SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10]


enum ChunkType {
	IHDR,
	PLTE,
	IDAT,
	IEND,
	acTL,
	fcTL,
	fdAT
}


enum ColorType {
	GREYSCALE = 0,
	TRUECOLOR = 2
	INDEXEDCOLOR = 3
	GREYSCALE_ALPHA = 4
	TRUECOLOR_ALPHA = 6
}


func _ready():
	make_crc_table()


var sequence = 0
func next_sequence():
	sequence += 1
	return sequence

var thread

# 
func write_png(frames: Array, color_type: int, framerate: float):
	var start = OS.get_ticks_msec()
	
	sequence = 0
	
	# begin with png signature
	var data = PoolByteArray(PNG_SIGNATURE)
	
	var first_frame: Image = frames[0]
	# header chunk
	data.append_array(get_chunk(ChunkType.IHDR, get_IHDR(first_frame.get_width(), first_frame.get_height(), 8, color_type)))
	
	# animation control chunk
	data.append_array(get_chunk(ChunkType.acTL, get_acTL(frames.size())))
	
	# frame control chung and first frame
	data.append_array(get_chunk(ChunkType.fcTL, get_fcTL(0, first_frame.get_width(), first_frame.get_height(), framerate)))
	data.append_array(get_chunk(ChunkType.IDAT, get_png_datastream(first_frame)))
	
	emit_signal("update_progress", {
		"step": "Writing frames",
		"value": 1,
		"max_value": frames.size()
	})
	
	for i in range(1, frames.size()):
		# frame control chunk
		var next_frame = frames[i]
		data.append_array(get_chunk(ChunkType.fcTL, get_fcTL(next_sequence(), next_frame.get_width(), next_frame.get_height(), framerate)))
		
		# frame data chunk
		var frame_data = int2array(next_sequence(), 4)
		frame_data.append_array(get_png_datastream(next_frame))
		data.append_array(get_chunk(ChunkType.fdAT, frame_data))
		
		# update progress
		emit_signal("update_progress", {
		"step": "Writing frames",
		"value": i + 1,
		"max_value": frames.size()
	})
		
	
	# end chunk
	data.append_array(get_chunk(ChunkType.IEND, PoolByteArray()))
	
	var file = File.new()
	file.open("res://test.png", File.WRITE)
	file.store_buffer(data)
	file.close()
	print("png written after %dms" % (OS.get_ticks_msec() - start))



func get_IHDR(width: int, height: int, bit_depth: int, color_type: int) -> PoolByteArray:
	var ihdr = PoolByteArray()
	
	ihdr.append_array(int2array(width, 4)) # width
	ihdr.append_array(int2array(height, 4)) # height
	ihdr.append(bit_depth) # bit depth
	ihdr.append(color_type) # Color type
	ihdr.append(0) # compression type
	ihdr.append(0) # filter method
	ihdr.append(0) # interlace method
	
	return ihdr


func get_acTL(num_frames: int, num_plays: int = 0) -> PoolByteArray:
	var actl = PoolByteArray()
	
	actl.append_array(int2array(num_frames, 4)) # num_frames
	actl.append_array(int2array(num_plays, 4)) # num_plays
	
	return actl


func get_fcTL(sequence_number: int, width: int, height: int, framerate: float) -> PoolByteArray:
	var fctl = PoolByteArray()
	
	var numerator = 1
	var denumerator = 1
	
	if framerate > 1.0:
		denumerator = round(framerate)
	elif framerate > 0.0:
		numerator = round(1.0 / framerate)
		
	
	fctl.append_array(int2array(sequence_number, 4)) # sequence_number
	fctl.append_array(int2array(width, 4)) # width
	fctl.append_array(int2array(height, 4)) # height
	fctl.append_array(int2array(0, 4)) # x_offset
	fctl.append_array(int2array(0, 4)) # y_offset
	fctl.append_array(int2array(numerator, 2)) # delay_num
	fctl.append_array(int2array(denumerator, 2)) # delay_den
	fctl.append(0) # dispose_op
	fctl.append(0) # dispose_op
	
	return fctl


# Each chunk consists of 3 or 4 fields
# Length, Chunk Type, [Chunk Data], CRC
func get_chunk(chunk_type: int, chunk_data: PoolByteArray) -> PoolByteArray:
	var chunk = PoolByteArray()
	
	# length
	chunk.append_array(get_length(chunk_data))
	
	var type_and_data = get_chunk_type_field(chunk_type)
	type_and_data.append_array(chunk_data)
	
	#type and data
	chunk.append_array(type_and_data)
	
	# crc
	chunk.append_array(get_crc(type_and_data))
	return chunk


# Each byte of a chunk type is restricted to the decimal values 65 to 90 and 97 to 122.
# These correspond to the uppercase and lowercase ISO 646 letters (A-Z and a-z) respectively for convenience in description and examination of PNG datastreams.
func get_chunk_type_field(chunk_type: int) -> PoolByteArray:
	var type_name: String = ChunkType.keys()[chunk_type]
	
	return type_name.to_ascii()
	

var crc_table = []

# Make the table for a ultra fast CRC
# crc table from https://www.w3.org/TR/PNG-CRCAppendix.html
func make_crc_table() -> void:
	var start = OS.get_ticks_msec()
	var c: int = 0
	for n in range(256):
		c = n
		for k in range(8):
			if c & 1:
				c = 0xedb88320 ^ (c >> 1)
			else:
				c = c >> 1;
		crc_table.append(c)
		
		


# Calculate the Cyclic redundancy check for a byte array
# https://en.wikipedia.org/wiki/Cyclic_redundancy_check#CRC-32_algorithm
# https://lxp32.github.io/docs/a-simple-example-crc32-calculation/
func get_crc(data: PoolByteArray) -> PoolByteArray:
	
	var crc = 0xFFFFFFFF
	
	for n in range(data.size()):
		crc = crc_table[(crc ^ data[n]) & 0xff] ^ (crc >> 8);

	
	crc = crc ^ 0xFFFFFFFF
	return int2array(crc, 4)


# get the length of a chunk as 4 byte byte array
func get_length(data: PoolByteArray) -> PoolByteArray:
	var length = data.size()
	
	return int2array(length, 4)


# convert an integer to a PoolByteArray representation
# value: the value to convert
# num_bytes: the number of bytes to convert to
func int2array(value: int, num_bytes: int) -> PoolByteArray:
	var array = PoolByteArray()
	
	for i in range(num_bytes):
		array.append(value >> (i * 8) & 0xFF)
	
	array.invert()
	return array


# convert a number from byte array presentation to an integer
func array2int(array: PoolByteArray) -> int:
	var value = 0
	array.invert()
	
	for i in array.size():
		value += array[i] << (i * 8)
	
	
	return value


# creates a png datastream from an image
func get_png_datastream(image: Image, filter_type: int = 0) -> PoolByteArray:
	var png_stream = PoolByteArray()
	
	var raw_data = image.get_data()
	
	var line_width = raw_data.size() / image.get_height()
	
	for line in range(image.get_height()):
		# each scanline is preceeded by the filter_type
		png_stream.append(filter_type)
		
		# then tha image data of the scanline
		var line_data = raw_data.subarray(line * line_width, (line + 1) * line_width - 1)
		png_stream.append_array(line_data)
	
	return png_stream.compress(File.COMPRESSION_DEFLATE)
