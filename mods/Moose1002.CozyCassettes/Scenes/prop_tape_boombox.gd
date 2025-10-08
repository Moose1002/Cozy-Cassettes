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
# Is youtube cassette currently loaded?
var _youtube_loaded = false
# Queue of URL's to play for the Youtube tape
var _url_queue = []
# Metadata for the currently loaded stream song
var _stream_metadata = null
# The last checked playback position of the current stream
var _last_stream_position = 0
# Iterator used to ensure a track has actually finished
var _stream_finished_counter = 0
# Check to determine if the next song is currently being fetched
var _awaiting_next_stream_load = false
# The boombox's UI
var _cassette_player_ui

# TODO: Test with multiple people, and document code

func _ready():
	# This allows the prop to call actor actions over the network
	custom_valid_actions = ["_load_cassette", "_unload_cassette", "_stop_player", "_play_player", "_fastforward", "_rewind", "_add_url_to_queue", "_remove_url_from_queue"]

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
		_cassette_player_ui.connect("add_url_to_queue", self, "_sync_add_url_to_queue")
		_cassette_player_ui.connect("remove_url_from_queue", self, "_sync_remove_url_from_queue")
		_cassette_player_ui.connect("slider_slid", self, "_change_volume")
		_cassette_player_ui.connect("cassette_ui_closed", self, "_on_cassette_ui_closed")
	
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

func _load_stream_url(url):
	CozyCassettes.load_stream_url(url, audio)
	_awaiting_next_stream_load = false

# Called when the current track finishes.
# Moves to the next track if not fastforwarding/rewinding
func _on_track_finish():
	# Remove the queue entry
	_cassette_player_ui.on_track_end()
	# TODO: I might be able to have a background audiostream that can store the next song so there's no delay between tracks?
	if _youtube_loaded:
		_awaiting_next_stream_load = true
		_cassette_tape_timer = 0
		_stream_metadata = null
		if not _url_queue.empty():
			_url_queue.remove(0)
			if not _url_queue.empty():
				_cassette_player_ui.update_song("[LOADING SONG]")
				_load_stream_url(_url_queue[0])
			else:
				_cassette_player_ui._change_queue_button_text("PLAY")
				audio.stream_paused = true
		return
	
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
	
	_unload_cassette()
	if cassette_id == "youtube_tape":
		_youtube_loaded = true
		return
	
	_loaded_cassette_dir = CozyCassettes.load_media_dir(cassette_id, CozyCassettes.CASSETTE_DIR)
	if (_loaded_cassette_dir == ""): 
		print(PREFIX + "Cassette not found, canceling client load.")
		return
		
	_cassette_data = CozyCassettes.load_cassette_json(cassette_id, CozyCassettes.CASSETTE_DIR, CozyCassettes.TAPE_JSON_DICT)
	
	# This lets other players see what the owner's boombox is playing.
	# Potentially refactor in the future to allow everyone to control your boombox.
	# Also maybe a lock option?
	if not controlled:
		interact.text = _cassette_data["name"]
	
	_song_files = CozyCassettes.get_media_files(_loaded_cassette_dir, CozyCassettes.VALID_FILE_TYPES)
	_song_files.sort() # A shuffle function could be added here for digital tapes
	
	#_update_timer()
	# Make sure that the tape directory actually has music files before we try to load anything
	if (_song_files.size() > 0):
		_load_audio_file()

# Clears the array of loaded song paths and stops all music
func _unload_cassette():
	audio.stream_paused = true
	audio.stream = null
	_youtube_loaded = false
	_url_queue.clear()
	_loaded_cassette_dir = ""
	_song_files.clear()
	_cassette_tape_timer = 0
	_cassette_track = 1 # Magic cassette play that rewinds your tapes when ejected :P
	_update_timer()
	_cassette_player_ui.update_song("")
	_cassette_player_ui._change_queue_button_text("PLAY")
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
	if (_loaded_cassette_dir == "" and (not _youtube_loaded)):
		return
	if _youtube_loaded and _url_queue.empty():
		return	
	if (audio.playing && audio.stream_paused == false): 
		return
	
	sfx.stream = CASSETTE_PLAY
	sfx.play()

# TODO: Stream fast forwarding?

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
	if _youtube_loaded: return
	if (_cassette_data and _cassette_data["type"] == "digital"):
		_digital_fastfoward()
		return
	_stop_player()
	_scrubbing_state = 1
	_scrubbing_stop_sfx_played = false
	sfx.stream = CASSETTE_SCRUB
	sfx.play()

func _rewind():
	if _youtube_loaded: return
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

# Adds provided url to the queue of stream songs to play
# If the queue is empty when a song is added, then it goes ahead and loads the song
func _add_url_to_queue(url):
	if _url_queue.empty():
		_load_stream_url(url)
	_url_queue.append(url)
	print(_url_queue)

# Removes the url at the given index
func _remove_url_from_queue(index):
	_url_queue.remove(index)
	print(_url_queue)

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

func _sync_add_url_to_queue(url):
	_add_url_to_queue(url)
	Network._send_actor_action(actor_id, "_add_url_to_queue", [url], true)

func _sync_remove_url_from_queue(index):
	_remove_url_from_queue(index)
	Network._send_actor_action(actor_id, "_remove_url_from_queue", [index], true)

func _on_cassette_ui_closed():
	interact.get_child(0).disabled = false

func _on_Interactable__activated():
	if controlled:
		_cassette_player_ui.show()
		interact.get_child(0).disabled = true

# Updates the UI metadata, and tracks if the current stream song has finished
func _update_stream_info():
	if _awaiting_next_stream_load:
		return
	
	if _stream_metadata == null:
		return
	var current_position = CozyCassettes.get_loaded_song_playback_position()	
	var duration = _stream_metadata.get("duration")
	if duration and current_position:
		var title = _stream_metadata.get("title", "Unknown")
		# AudioStream can't get the metadata of a playlist so here is my janky way to prevent
		# the meta data of the previous song from lingering when a playlist is playing.
		if (not _url_queue.empty()) and (("playlist?list=" in _url_queue[0]) or ("index=" in _url_queue[0])):
			title = "Playlist"
			_cassette_player_ui.update_song(title)
			_cassette_player_ui._update_queue_entry(title, 0)
			# Wait till the song starts playing to update the metadata
		# Only change the title if the song has actually started playing/hasn't ended.
		if not (current_position <= 0 or round(current_position) >= duration):
			if title:
				# TODO: Only have this update if the song title has changed?
				_cassette_player_ui.update_song(title)
				_cassette_player_ui._update_queue_entry(title, 0)
				_cassette_player_ui._change_queue_button_text("QUEUE")
	
		# Custom track finished logic
		if current_position == _last_stream_position and current_position > 0:
			# Need to keep a count to make sure this check has been run multiple times
			# because this statement can be true twice in a row which triggers a false positive.
			if _stream_finished_counter > 10: # Have never seen it get above 2
				_on_track_finish()
			_stream_finished_counter += 1
		else:
			_stream_finished_counter = 0
			_last_stream_position = current_position
		
# Process audio scrubbing
func _physics_process(delta):
	if (!audio.stream_paused):
		_cassette_tape_timer += 0.017 # This is close enough to a second
		_update_timer()
		if _youtube_loaded:
			_stream_metadata = CozyCassettes.get_loaded_song_metadata()
			_update_stream_info()
		
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

	
