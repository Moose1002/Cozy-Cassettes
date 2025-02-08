extends PlayerProp

onready var audio = $AudioStreamPlayer3D
onready var sfx = $AudioStreamPlayer3DSFX
onready var interact = $Interactable

onready var CassettePlayerGUI = preload("res://mods/Moose1002.CozyCassettes/UI/cassette_player_menu.tscn")

onready var Lure = get_node("/root/SulayreLure")
onready var CozyCassettes = get_node("/root/Moose1002CozyCassettes")

const PREFIX = "[CozyCassettes]: "
const CASSETTE_PLAY = preload("res://mods/Moose1002.CozyCassettes/Sounds/cassette_player_play.mp3")
const CASSETTE_STOP = preload("res://mods/Moose1002.CozyCassettes/Sounds/cassette_player_stop.mp3")
const CASSETTE_SCRUB = preload("res://mods/Moose1002.CozyCassettes/Sounds/cassette_player_wind.mp3")

# Parsed JSON data for the loaded cassette tape
var _cassette_data
# The track on the casssete tape that is currently playing
var _cassette_track = 1
# The current file system directory of that inserted cassette
var _loaded_cassette_dir = ""
# Paths to all music files in the loaded cassette directory
var _song_files = []
# Tracks if the audio is rewinding, fastforwarding, or playing
# -1 = RW, 0 = Playing, 1 = FF
var _scrubbing_state = 0
# The speed that the tape FF/RW
var _scrubbing_speed = 0.2
# Tracks the stop SFX to prevent it replaying
var _scrubbing_stop_sfx_played = false
# Timer tracker
var _cassette_tape_timer = 0
# File name of current song playing to display on cassette player UI
var _current_song = ""

# The boombox's UI
var _cassette_player_ui

func _ready():
	# This allows the prop to call actor actions over the network
	custom_valid_actions = ["_load_cassette", "_unload_cassette", "_stop_player", "_play_player", "_fastforward", "_rewind"]

	# Initialize Cassette Player GUI
	if (CassettePlayerGUI):
		_cassette_player_ui = CassettePlayerGUI.instance()
		_cassette_player_ui.hide()
		get_tree().root.add_child(_cassette_player_ui)
		_cassette_player_ui.connect("load_cassette", self, "_sync_load_cassette")
		_cassette_player_ui.connect("unload_cassette", self, "_sync_unload_cassette")
		_cassette_player_ui.connect("play_cassette", self, "_sync_play_player")
		_cassette_player_ui.connect("stop_cassette", self, "_sync_stop_player")
		_cassette_player_ui.connect("fastforward", self, "_sync_fastforward")
		_cassette_player_ui.connect("rewind", self, "_sync_rewind")
		_cassette_player_ui.connect("slider_slid", self, "_change_volume")
	
	audio.stream_paused = true

# Update's the GUI second timer	
func _update_timer():
	# 4 digit display rollover
	if (_cassette_tape_timer > 10000):
		_cassette_tape_timer = 0
	elif (_cassette_tape_timer < 0):
		_cassette_tape_timer = 9999
	var formatted_time = str(_cassette_tape_timer)
	formatted_time = formatted_time.split(".")[0].pad_zeros(4)
	_cassette_player_ui.update_timer(formatted_time)
	
# Loads the audio file located at index _cassette_track in the loaded cassette directory
# A int can be passed to load a specific track in the directory
func _load_audio_file(track = _cassette_track, should_pause = true, play_from_start = true):
	#print(PREFIX + "Loading track " + str(track))
	audio.stream = CozyCassettes.loadfile(_song_files[track - 1])
	if (_cassette_data["type"] == "digital"):
		_cassette_player_ui.update_song(_song_files[track - 1].get_basename().split("/")[-1])
		
	if (play_from_start): audio.play()
	else: audio.play(audio.stream.get_length())
	audio.stream_paused = should_pause

# Called when the current track finishes.
# Moves to the next track if not fastforwarding/rewinding
func _on_track_finish():
	if (_scrubbing_state != 0): return
	# Digital cassettes use song timer instead of tape timer
	if (_cassette_data["type"] == "digital"): 
		_cassette_tape_timer = 0
		
	_cassette_track += 1
	if _cassette_track > _song_files.size(): 
		_cassette_track = 1
		return
	_load_audio_file(_cassette_track, false)	

# Called on play/pause after sfx has played
func _on_sfx_finish():
	if (sfx.stream == CASSETTE_PLAY): # On play
		if (audio.stream_paused):
			audio.stream_paused = false
			return
	elif (sfx.stream == CASSETTE_STOP): # On stop/pause
		return
	
# Get an array of paths to music files in the directory associated with the given cassette_id
func _load_cassette(cassette_id):
	# This lets other players see what the owner's boombox is playing.
	# Potentially refactor in the future to allow everyone to control your boombox.
	# Also maybe a lock option?
	if not controlled:
		interact.text = "Playing: " + CozyCassettes.load_cassette_json(cassette_id)["name"]
		
	_loaded_cassette_dir = CozyCassettes.load_cassette_dir(cassette_id)
	if (_loaded_cassette_dir == ""): 
		print(PREFIX + "Cassette not found, canceling client load.")
		return
	_cassette_data = CozyCassettes.load_cassette_json(cassette_id)
	_song_files = CozyCassettes.get_song_files(_loaded_cassette_dir)
	_song_files.sort()
	_cassette_track = 1 # Magic cassette play that rewinds your tapes when ejected :P
	_cassette_tape_timer = 0
	_update_timer()
	_cassette_player_ui.update_song("")
	sfx.stream = CASSETTE_STOP
	sfx.play()
	# Make sure that the tape directory actually has music files before we try to load anything
	if (_song_files.size() > 0):
		_load_audio_file()

# Clears the array of loaded song paths and stops all music
func _unload_cassette():
	audio.stream_paused = true
	_loaded_cassette_dir = ""
	_song_files = []	
	_cassette_tape_timer = 0
	_update_timer()
	_cassette_player_ui.update_song("")
	_scrubbing_state = 0
	_scrubbing_stop_sfx_played = false
	audio.stop()
	sfx.stream = CASSETTE_STOP
	sfx.play()

# Pauses the current audio
# Does nothing if the audio is already paused AND the tape isn't scrubbing
func _stop_player():
	if (audio.stream_paused == true && _scrubbing_state == 0): return
	_scrubbing_state = 0
	if (_scrubbing_stop_sfx_played): return
	_scrubbing_stop_sfx_played = true
	audio.stream_paused = true
	sfx.stream = CASSETTE_STOP
	sfx.play()

# If a cassette is loaded stop scrubbing and unpause the audio
# This function doesn't actually unpause the audio stream, that is called after the SFX finishes
func _play_player():
	_scrubbing_state = 0
	_scrubbing_stop_sfx_played = false
	if (_loaded_cassette_dir == ""):
		return
	if (audio.playing && audio.stream_paused == false): return
	
	sfx.stream = CASSETTE_PLAY
	sfx.play()

func _digital_fastfoward():
	_cassette_track += 1
	_cassette_tape_timer = 0
	if (_cassette_track > _song_files.size()):
		_cassette_track = 1
	_load_audio_file(_cassette_track, false)

func _digital_rewind():
	_cassette_track -= 1
	_cassette_tape_timer = 0
	if (_cassette_track == 0):
		_cassette_track = 1
	_load_audio_file(_cassette_track, false)

func _fastforward():
	if (_cassette_data["type"] == "digital"):
		_digital_fastfoward()
		return
	_stop_player()
	_scrubbing_state = 1
	_scrubbing_stop_sfx_played = false
	sfx.stream = CASSETTE_SCRUB
	sfx.play()

func _rewind():
	if (_cassette_data["type"] == "digital"):
		_digital_rewind()
		return
	_stop_player()
	_scrubbing_state = -1
	_scrubbing_stop_sfx_played = false
	sfx.stream = CASSETTE_SCRUB
	sfx.play()

func _change_volume(volume):
	audio.unit_db = volume

# Network sync calls
func _sync_load_cassette(cassette_id):
	_load_cassette(cassette_id)
	Network._send_actor_action(actor_id, "_load_cassette", [cassette_id], true)

func _sync_unload_cassette():
	_unload_cassette()
	Network._send_actor_action(actor_id, "_unload_cassette", [], true)

func _sync_stop_player():
	_stop_player()
	Network._send_actor_action(actor_id, "_stop_player", [], true)

func _sync_play_player():
	_play_player()
	Network._send_actor_action(actor_id, "_play_player", [], true)

func _sync_fastforward():
	_fastforward()
	Network._send_actor_action(actor_id, "_fastforward", [], true)

func _sync_rewind():
	_rewind()
	Network._send_actor_action(actor_id, "_rewind", [], true)

func _on_Interactable__activated():
	if controlled:
		_cassette_player_ui.show()

# Process audio scrubbing
func _physics_process(delta):
	if (!audio.stream_paused):
		_cassette_tape_timer += 0.017 # This is close enough to a second
		_update_timer()
	# Stop scrubbing SFX when FW/RW is stopped
	if (_scrubbing_state == 0 && sfx.stream == CASSETTE_SCRUB):
		sfx.stop()
		sfx.stream = CASSETTE_STOP
		sfx.play()
		return
		
	if (_scrubbing_state == 1): #FF
		var audio_position = audio.get_playback_position()
		
		# Reached end of track
		if (audio_position >= audio.stream.get_length()):
			_cassette_track += 1
			# Reached end of cassette
			if (_cassette_track > _song_files.size()): 
				_cassette_track = 1
				_load_audio_file()	
				_scrubbing_state = 0
				return
			_load_audio_file()
			return
			
		audio_position += _scrubbing_speed
		_cassette_tape_timer += _scrubbing_speed
		_update_timer()
		audio.seek(audio_position)
		
	elif (_scrubbing_state == -1): #RW
		var audio_position = audio.get_playback_position()
			
		# Reached start of track	
		if (audio_position <= _scrubbing_speed):
			_cassette_track -= 1
			# Reached start of cassette
			if (_cassette_track == 0): 
				_cassette_track = 1
				_load_audio_file()	
				_scrubbing_state = 0
				return
			_load_audio_file(_cassette_track, true, false)
			return
				
		audio_position -= _scrubbing_speed
		_cassette_tape_timer -= _scrubbing_speed
		_update_timer()
		audio.seek(audio_position)
