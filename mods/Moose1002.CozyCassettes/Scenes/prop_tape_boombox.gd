extends PlayerProp

onready var audio = $AudioStreamPlayer3D
onready var sfx = $AudioStreamPlayer3DSFX
onready var CassettePlayerGUI = preload("res://mods/Moose1002.CozyCassettes/UI/cassette_player_menu.tscn")

onready var Lure = get_node("/root/SulayreLure")
onready var Moose1002CozyCassettes = get_node("/root/Moose1002CozyCassettes")

const CASSETTE_PLAY = preload("res://mods/Moose1002.CozyCassettes/Sounds/cassette_player_play.mp3")
const CASSETTE_STOP = preload("res://mods/Moose1002.CozyCassettes/Sounds/cassette_player_stop.mp3")
const CASSETTE_SCRUB = preload("res://mods/Moose1002.CozyCassettes/Sounds/cassette_player_wind.wav")

# The track on the casssete tape that is currently playing
var _cassette_track = 1
# The current file system directory of that inserted cassette
var _loaded_cassette_dir = ""
# Paths too all music files in the loaded cassette directory
var _song_files = []
var _scrubbing_state = 0
var _scrubbing_speed = 0.2
var _scrubbing_stop_sfx_played = false
var _cassette_tape_duration = 0
var _cassette_tape_timer = 0

var _cassette_player_ui

func _ready():
	# Initialize Cassette Player GUI
	audio.stream_paused = true
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

func _update_timer():
	var formatted_time = str(_cassette_tape_timer)
	formatted_time = formatted_time.split(".")[0].pad_zeros(4)
	_cassette_player_ui.update_timer(formatted_time)
	
# Loads the audio file located at index _cassette_track in the loaded cassette directory
# A int can be passed to load a specific track in the directory
func _load_audio_file(track = _cassette_track, should_pause = true, play_from_start = true):
	print("Loading track " + str(track))
	audio.stream = Moose1002CozyCassettes.loadfile(_song_files[track - 1])
	if (play_from_start): audio.play()
	else: audio.play(audio.stream.get_length())
	audio.stream_paused = should_pause

# Called when the current track finishes.
# Moves to the next track if not fastforwarding/rewinding
func _on_track_finish():
	if (_scrubbing_state != 0): return
	print("Track " + str(_cassette_track) + " finished playing!")
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
	_loaded_cassette_dir = Moose1002CozyCassettes.get_cassette_dir(cassette_id)
	_song_files = Moose1002CozyCassettes.get_song_files(_loaded_cassette_dir)
	_cassette_track = 1 # Magic cassette play that rewinds your tapes when ejected :P
	_cassette_tape_timer = 0
	_update_timer()
	sfx.stream = CASSETTE_STOP
	sfx.play()
	# Make sure that the tape directory actually has music files before we try to load anything
	if (_song_files.size() > 0):
		_load_audio_file()

# Clears the array of load song paths and stops all music	
func _unload_cassette():
	_loaded_cassette_dir = ""
	_song_files = []	
	_cassette_tape_timer = 0
	_update_timer()
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
				
func _fastforward():
	_stop_player()
	_scrubbing_state = 1
	_scrubbing_stop_sfx_played = false
	sfx.stream = CASSETTE_SCRUB
	sfx.play()
			
func _rewind():
	_stop_player()
	_scrubbing_state = -1
	_scrubbing_stop_sfx_played = false
	sfx.stream = CASSETTE_SCRUB
	sfx.play()

# Network sync calls
func _sync_load_cassette(tape):
	_load_cassette(tape)
	Network._send_actor_action(actor_id, "_load_cassette", [tape], true)

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
	_cassette_player_ui.show()

# Process audio scrubbing
func _physics_process(delta):
	if (!audio.stream_paused):
		_cassette_tape_timer += 0.017
		_update_timer()
	# Stop scrubbing SFX when FW/RW is stopped
	if (_scrubbing_state == 0 && sfx.stream == CASSETTE_SCRUB):
		sfx.stop()
		sfx.stream = CASSETTE_STOP
		sfx.play()
		return
		
	if (_scrubbing_state == 1): #FF
		var audio_position = audio.get_playback_position()
		
		if (audio_position >= audio.stream.get_length()):
			print("Reached end of track")
			_cassette_track += 1
			if _cassette_track > _song_files.size(): 
				print("Reached end of cassette")
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
			
		if (audio_position <= _scrubbing_speed):
			print("Reached start of track")
			_cassette_track -= 1
			if (_cassette_track == 0): 
				print("Reached start of cassette")
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
