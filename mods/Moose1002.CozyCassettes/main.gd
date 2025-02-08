extends Node

# Cozy Casettes v0.3.0 by Moose1002
# Feel free to reach out to me if you have any questions or suggestions!
# I'm happy to hear them!

const MOD_ID = "Moose1002.CozyCassettes"
const PREFIX = "[CozyCassettes]: "
#const CASSETTE_DIR = "res://mods/Moose1002.CozyCassettes/Cassettes/"
var CASSETTE_DIR = OS.get_executable_path().get_base_dir() + "/Cassettes/"

# TODO: Get .wav working
const VALID_FILE_TYPES = ["mp3", "ogg", "png"]
const TAPE_JSON_DICT = {
	name = "",
	description = "default",
	design = "default",
	type = "analog"
}
onready var Lure = get_node("/root/SulayreLure")

# Returns the path to the provided cassette's song directory
func load_cassette_dir(cassette_id: String):
	var dir = Directory.new()
	dir.open(CASSETTE_DIR)
	dir.list_dir_begin()
	
	var dir_name = dir.get_next()
	while dir_name != "":
		if (dir_name.to_lower().replace(" ", "_") + "_tape" == cassette_id):
			return CASSETTE_DIR + dir_name
		dir_name = dir.get_next()
	return ""	

# Returns an array of all song file paths in a directory
func get_song_files(path: String):
	var song_files = []
	var dir = Directory.new()
	
	dir.open(path)
	dir.list_dir_begin()
	
	var song_file_name = dir.get_next()
	while song_file_name != "":
		if (song_file_name.begins_with(".") or song_file_name.ends_with(".import") or song_file_name == "tape.json"):
			song_file_name = dir.get_next()	
			continue
		elif (VALID_FILE_TYPES.find(song_file_name.get_extension()) == -1):
			print(PREFIX + "Invalid file type found: " + song_file_name)
			song_file_name = dir.get_next()	
			continue
		song_files.append(path + "/" + song_file_name)
		song_file_name = dir.get_next()	
	return song_files

# Returns a readable string from the cassette id
func format_cassette_id(cassette_id: String):
	var formatted_cassetted_id = cassette_id.trim_suffix("_tape").capitalize()
	return formatted_cassetted_id

# This updates old json files that might be missing field.
# This is just a failsafe and shouldn't be called more than once.
func _update_json(cassette_id: String, cassette_tape_data: Dictionary):
	print(PREFIX + "Old tape.json found, attemping update.")
	
	var json = File.new()
	var json_dir = load_cassette_dir(cassette_id) + "/tape.json"
	json.open(json_dir, File.WRITE)
	
	var json_dict = TAPE_JSON_DICT
	json_dict["name"] = cassette_tape_data["name"]
	json_dict["description"] = "default"
	json_dict["design"] = cassette_tape_data["design"]
	json_dict["type"] = cassette_tape_data["type"]
	
	json.store_string(JSON.print(json_dict, "\t"))
	json.close()
	
	return json_dict

# Process the tape.json data for the provided cassette tape
# If tape.json exists returns the tape's data dictionary
# If tape.json doesn't exist creates it
func load_cassette_json(cassette_id: String):
	var json = File.new()
	var json_dir = load_cassette_dir(cassette_id) + "/tape.json"
	
	# If the file already exists read and return the data
	if (json.file_exists(json_dir)):	
		json.open(json_dir, File.READ)
		var cassette_tape_data = JSON.parse(json.get_as_text()).result	
		json.close()
		
		if (typeof(cassette_tape_data) == TYPE_DICTIONARY):
			if (!cassette_tape_data.has("description")):
				pass
			return cassette_tape_data
	# Else make the file
	else:
		print(PREFIX + "tape.json not found for " + cassette_id + ". Creating it!")
		json.open(json_dir, File.WRITE)
		var json_dict = TAPE_JSON_DICT
		
		json_dict["name"] = format_cassette_id(cassette_id)
		json.store_string(JSON.print(json_dict, "\t"))
		json.close()
		return json_dict

# UNUSED - Potential update feature
# Patches the radio bus to add effects to create a more cassette like sound
func patch_cassette_audiobus():
	var audioBusID = AudioServer.get_bus_index("Radio")
	# Add cassette like audio effects
	var cassetteEffect = AudioEffectFilter.new()
	cassetteEffect.cutoff_hz = 250 # Low pass test
	AudioServer.add_bus_effect(audioBusID, cassetteEffect)

# Matches the cassette_id to it's tape resource file
func _get_cassette_tape_resource(cassette_data):
	
	# TODO: Reafactor this to not use a switch statement and instead just use the path
	# Don't feel like doing it rn
	match cassette_data["design"]:
		"default":
			if (cassette_data["type"] == "digital"):
				return "mod://Tapes/Resources/digital_tape.tres" 
			return "mod://Tapes/Resources/tape_red.tres"
		# Basic Colors
		"red":
			return "mod://Tapes/Resources/tape_red.tres"
		"black":
			return "mod://Tapes/Resources/tape_black.tres"
		"green":
			return "mod://Tapes/Resources/tape_green.tres"	
		"pink":
			return "mod://Tapes/Resources/tape_pink.tres"
		"yellow":
			return "mod://Tapes/Resources/tape_yellow.tres"
		# Solid Colors
		"solid_pink":
			return "mod://Tapes/Resources/tape_solid_pink.tres"
		"solid_red":
			return "mod://Tapes/Resources/tape_solid_red.tres"	
		"solid_white":
			return "mod://Tapes/Resources/tape_solid_white.tres"	
		"solid_yellow":
			return "mod://Tapes/Resources/tape_solid_yellow.tres"		
		# Brand Knockoffs
		"max":
			return "mod://Tapes/Resources/tape_max.tres"
		"max2":
			return "mod://Tapes/Resources/tape_max2.tres"
		# Special
		"digital":
			return "mod://Tapes/Resources/digital_tape.tres"
		"og":
			return "mod://Tapes/Resources/tape_og.tres"		
		"pride":
			return "mod://Tapes/Resources/tape_pride.tres"
		"weezer":
			return "mod://Tapes/Resources/tape_weezer.tres"	
		_:
			if (cassette_data["type"] == "digital"):
				return "mod://Tapes/Resources/digital_tape.tres"
			return "mod://Tapes/Resources/tape_red.tres"

# Sets the provided cassette's texture to the one located at custom_texture
func _set_custom_cassette_texture(cassette_id: String, custom_texture: String):
	var texture = ImageTexture.new()
	var image = Image.new()
	image.load(custom_texture)
	texture.create_from_image(image, 1)
	# Can't set this to an Image directly so we create a ImageTexture
	Globals.item_data[MOD_ID + "." + cassette_id]["file"].icon = texture

# Build cassette items from the Cassettes folder
func _build_cassettes():
	var dir = Directory.new()
	dir.open(CASSETTE_DIR)
	dir.list_dir_begin(true, true)
	
	var cassette_dir = dir.get_next()
	# Iterate through created Cassette playlist folders
	while cassette_dir != "":
		
		var cassette_id = cassette_dir
		cassette_id = cassette_id.to_lower().replace(" ", "_") + "_tape"
	
		# This calls to create tape.json if it doesn't already exist
		var cassette_data = load_cassette_json(cassette_id)
		# Update old jsons with new fields
		if (!cassette_data.has("description")):
			cassette_data = _update_json(cassette_id, cassette_data)
		
		var cassette_resource = _get_cassette_tape_resource(cassette_data)
		var custom_resource = load_cassette_dir(cassette_id) + "/tape.png"
		
		## Register Cassette Tape ##
		print(PREFIX + "Registering Cassette with ID: " + cassette_id)
		Lure.add_content(MOD_ID, cassette_id, cassette_resource, [Lure.FLAGS.FREE_UNLOCK])
		# Create a unique resource so we can save unique data to it
		Globals.item_data[MOD_ID + "." + cassette_id]["file"] = Globals.item_data[MOD_ID + "." + cassette_id]["file"].duplicate()
		
		# Set name and descriptions to tapes
		Globals.item_data[MOD_ID + "." + cassette_id]["file"].item_name = cassette_data["name"]
		if (cassette_data["description"] != null and cassette_data["description"] != "default"):
			Globals.item_data[MOD_ID + "." + cassette_id]["file"].item_description = cassette_data["description"]
		
		# If there's a tape.png then override the texture with the custom one
		if (dir.file_exists(custom_resource)):
			print(PREFIX + "Custom texture found for " + cassette_id + ", overriding texture.")
			_set_custom_cassette_texture(cassette_id, custom_resource)
			
		cassette_dir = dir.get_next()

func _ready():
	var cassette_dir = Directory.new()
	if (not cassette_dir.dir_exists(CASSETTE_DIR)):
		print(PREFIX + "Cassette folder not found. Creating one!")
		cassette_dir.make_dir(CASSETTE_DIR)
	if Lure:
		_build_cassettes()
		Lure.add_content(MOD_ID, "prop_tape_boombox", "mod://Scenes/prop_tape_boombox.tres", [Lure.FLAGS.FREE_UNLOCK])
		Lure.add_actor(MOD_ID, "prop_tape_boombox", "mod://Scenes/prop_tape_boombox.tscn")
	
	print(PREFIX + "CozyCassettes Loaded!")
	
#GDScriptAudioImport v0.1

#MIT License
#
#Copyright (c) 2020 Gianclgar (Giannino Clemente) gianclgar@gmail.com
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

#I honestly don't care that much, Kopimi ftw, but it's my little baby and I want it to look nice :3

func report_errors(err, filepath):
	# See: https://docs.godotengine.org/en/latest/classes/class_@globalscope.html#enum-globalscope-error
	var result_hash = {
		ERR_FILE_NOT_FOUND: "File: not found",
		ERR_FILE_BAD_DRIVE: "File: Bad drive error",
		ERR_FILE_BAD_PATH: "File: Bad path error.",
		ERR_FILE_NO_PERMISSION: "File: No permission error.",
		ERR_FILE_ALREADY_IN_USE: "File: Already in use error.",
		ERR_FILE_CANT_OPEN: "File: Can't open error.",
		ERR_FILE_CANT_WRITE: "File: Can't write error.",
		ERR_FILE_CANT_READ: "File: Can't read error.",
		ERR_FILE_UNRECOGNIZED: "File: Unrecognized error.",
		ERR_FILE_CORRUPT: "File: Corrupt error.",
		ERR_FILE_MISSING_DEPENDENCIES: "File: Missing dependencies error.",
		ERR_FILE_EOF: "File: End of file (EOF) error."
	}
	if err in result_hash:
		print(PREFIX + "Error: ", result_hash[err], " ", filepath)
	else:
		print(PREFIX + "Unknown error with file ", filepath, " error code: ", err)

func loadfile(filepath):
	var file = File.new()
	var err = file.open(filepath, File.READ)
	if err != OK:
		report_errors(err, filepath)
		file.close()
		return AudioStreamSample.new()

	var bytes = file.get_buffer(file.get_len())
	# if File is wav
	if filepath.ends_with(".wav"):
		var newstream = AudioStreamSample.new()

		#---------------------------
		#parrrrseeeeee!!! :D
		
		var bits_per_sample = 0
		var i = 0
		while true:
			if i >= len(bytes) - 4: # Failsafe, if there is no data bytes
				print(PREFIX + "Data byte not found")
				break
				
			var those4bytes = str(char(bytes[i])+char(bytes[i+1])+char(bytes[i+2])+char(bytes[i+3]))
			
			if those4bytes == "RIFF": 
				print ("RIFF OK at bytes " + str(i) + "-" + str(i+3))
				#RIP bytes 4-7 integer for now
			if those4bytes == "WAVE": 
				print ("WAVE OK at bytes " + str(i) + "-" + str(i+3))

			if those4bytes == "fmt ":
				print ("fmt OK at bytes " + str(i) + "-" + str(i+3))
				
				#get format subchunk size, 4 bytes next to "fmt " are an int32
				var formatsubchunksize = bytes[i+4] + (bytes[i+5] << 8) + (bytes[i+6] << 16) + (bytes[i+7] << 24)
				print ("Format subchunk size: " + str(formatsubchunksize))
				
				#using formatsubchunk index so it's easier to understand what's going on
				var fsc0 = i+8 #fsc0 is byte 8 after start of "fmt "

				#get format code [Bytes 0-1]
				var format_code = bytes[fsc0] + (bytes[fsc0+1] << 8)
				var format_name
				if format_code == 0: format_name = "8_BITS"
				elif format_code == 1: format_name = "16_BITS"
				elif format_code == 2: format_name = "IMA_ADPCM"
				else: 
					format_name = "UNKNOWN (trying to interpret as 16_BITS)"
					format_code = 1
				print ("Format: " + str(format_code) + " " + format_name)
				#assign format to our AudioStreamSample
				newstream.format = format_code
				
				#get channel num [Bytes 2-3]
				var channel_num = bytes[fsc0+2] + (bytes[fsc0+3] << 8)
				print ("Number of channels: " + str(channel_num))
				#set our AudioStreamSample to stereo if needed
				if channel_num == 2: newstream.stereo = true
				
				#get sample rate [Bytes 4-7]
				var sample_rate = bytes[fsc0+4] + (bytes[fsc0+5] << 8) + (bytes[fsc0+6] << 16) + (bytes[fsc0+7] << 24)
				print ("Sample rate: " + str(sample_rate))
				#set our AudioStreamSample mixrate
				newstream.mix_rate = sample_rate
				
				#get byte_rate [Bytes 8-11] because we can
				var byte_rate = bytes[fsc0+8] + (bytes[fsc0+9] << 8) + (bytes[fsc0+10] << 16) + (bytes[fsc0+11] << 24)
				print ("Byte rate: " + str(byte_rate))
				
				#same with bits*sample*channel [Bytes 12-13]
				var bits_sample_channel = bytes[fsc0+12] + (bytes[fsc0+13] << 8)
				print ("BitsPerSample * Channel / 8: " + str(bits_sample_channel))
				
				#aaaand bits per sample/bitrate [Bytes 14-15]
				bits_per_sample = bytes[fsc0+14] + (bytes[fsc0+15] << 8)
				print ("Bits per sample: " + str(bits_per_sample))
				
			if those4bytes == "data":
				assert(bits_per_sample != 0)
				
				var audio_data_size = bytes[i+4] + (bytes[i+5] << 8) + (bytes[i+6] << 16) + (bytes[i+7] << 24)
				print ("Audio data/stream size is " + str(audio_data_size) + " bytes")

				var data_entry_point = (i+8)
				print ("Audio data starts at byte " + str(data_entry_point))
				
				var data = bytes.subarray(data_entry_point, data_entry_point+audio_data_size-1)
				
				if bits_per_sample in [24, 32]:
					newstream.data = convert_to_16bit(data, bits_per_sample)
				else:
					newstream.data = data
				
				break # the data will be at the end, end searching here
			
			i += 1
			# end of parsing
			#---------------------------

		#get samples and set loop end
		var samplenum = newstream.data.size() / 4
		newstream.loop_end = samplenum
		newstream.loop_mode = 0 #change to 0 or delete this line if you don't want loop, also check out modes 2 and 3 in the docs
		return newstream  #:D

	#if file is ogg
	elif filepath.ends_with(".ogg"):
		var newstream = AudioStreamOGGVorbis.new()
		newstream.loop = false #set to false or delete this line if you don't want to loop
		newstream.data = bytes
		return newstream

	#if file is mp3
	elif filepath.ends_with(".mp3"):
		var newstream = AudioStreamMP3.new()
		newstream.loop = false #set to false or delete this line if you don't want to loop
		newstream.data = bytes
		return newstream

	else:
		print ("ERROR: Wrong filetype or format")
	file.close()

# Converts .wav data from 24 or 32 bits to 16
#
# These conversions are SLOW in GDScript
# on my one test song, 32 -> 16 was around 3x slower than 24 -> 16
#
# I couldn't get threads to help very much
# They made the 24bit case about 2x faster in my test file
# And the 32bit case abour 50% slower
# I don't wanna risk it always being slower on other files
# And really, the solution would be to handle it in a low-level language
func convert_to_16bit(data: PoolByteArray, from: int) -> PoolByteArray:
	print(PREFIX + "converting to 16-bit from %d" % from)
	var time = OS.get_ticks_msec()
	# 24 bit .wav's are typically stored as integers
	# so we just grab the 2 most significant bytes and ignore the other
	if from == 24:
		var j = 0
		for i in range(0, data.size(), 3):
			data[j] = data[i+1]
			data[j+1] = data[i+2]
			j += 2
		data.resize(data.size() * 2 / 3)
	# 32 bit .wav's are typically stored as floating point numbers
	# so we need to grab all 4 bytes and interpret them as a float first
	if from == 32:
		var spb := StreamPeerBuffer.new()
		var single_float: float
		var value: int
		for i in range(0, data.size(), 4):
			spb.data_array = data.subarray(i, i+3)
			single_float = spb.get_float()
			value = single_float * 32768
			data[i/2] = value
			data[i/2+1] = value >> 8
		data.resize(data.size() / 2)
	print(PREFIX + "Took %f seconds for slow conversion" % ((OS.get_ticks_msec() - time) / 1000.0))
	return data


# ---------- REFERENCE ---------------
# note: typical values doesn't always match

#Positions  Typical Value Description
#
#1 - 4      "RIFF"        Marks the file as a RIFF multimedia file.
#                         Characters are each 1 byte long.
#
#5 - 8      (integer)     The overall file size in bytes (32-bit integer)
#                         minus 8 bytes. Typically, you'd fill this in after
#                         file creation is complete.
#
#9 - 12     "WAVE"        RIFF file format header. For our purposes, it
#                         always equals "WAVE".
#
#13-16      "fmt "        Format sub-chunk marker. Includes trailing null.
#
#17-20      16            Length of the rest of the format sub-chunk below.
#
#21-22      1             Audio format code, a 2 byte (16 bit) integer. 
#                         1 = PCM (pulse code modulation).
#
#23-24      2             Number of channels as a 2 byte (16 bit) integer.
#                         1 = mono, 2 = stereo, etc.
#
#25-28      44100         Sample rate as a 4 byte (32 bit) integer. Common
#                         values are 44100 (CD), 48000 (DAT). Sample rate =
#                         number of samples per second, or Hertz.
#
#29-32      176400        (SampleRate * BitsPerSample * Channels) / 8
#                         This is the Byte rate.
#
#33-34      4             (BitsPerSample * Channels) / 8
#                         1 = 8 bit mono, 2 = 8 bit stereo or 16 bit mono, 4
#                         = 16 bit stereo.
#
#35-36      16            Bits per sample. 
#
#37-40      "data"        Data sub-chunk header. Marks the beginning of the
#                         raw data section.
#
#41-44      (integer)     The number of bytes of the data section below this
#                         point. Also equal to (#ofSamples * #ofChannels *
#                         BitsPerSample) / 8
#
#45+                      The raw audio data.            

