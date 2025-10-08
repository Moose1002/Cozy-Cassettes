extends Control

onready var cassette_id_label = $cassette_id
onready var cassette_timer_label = $timer
onready var item_icon = $item
onready var song_label = $song_title
onready var url_input = $YoutubePanel/url_input
onready var volume_slider = $volume
onready var youtube_panel = $YoutubePanel
onready var queue_container = $YoutubePanel/Panel/ScrollContainer/QueueContainer
onready var queue_button = $YoutubePanel/queue_button

onready var CozyCassettes = get_node("/root/Moose1002CozyCassettes")
onready var VintageVideo = get_node("/root/Moose1002VintageVideo")

onready var _queue_entry_syle = preload("res://Assets/Themes/panel_med.tres")
onready var _queue_entry_font = preload("res://Assets/Themes/main_font_tiny.tres")

var _chosen_item = 0

signal load_cassette(cassette_id)
signal unload_cassette()
signal play_cassette(path)
signal stop_cassette()
signal fastforward()
signal rewind()
signal slider_slid(volume)
signal cassette_ui_closed()
signal add_url_to_queue(url)
signal remove_url_from_queue(index)

func _ready():
	PlayerData.connect("_return_item_choice", self, "_update_item")
	item_icon._setup_item(0)

func show(): visible = true
func hide(): visible = false

func _on_close_button_pressed():
	hide()
	emit_signal("cassette_ui_closed")

func _on_play_button_pressed():
	if _chosen_item == 0: 
		return
	emit_signal("play_cassette")
	
func _on_stop_button_pressed():
	emit_signal("stop_cassette")
	
func _on_load_cassette_pressed():
	PlayerData.emit_signal("_request_item_choice", [], 1, 1, "", false)
	
func _on_eject_button_pressed():
	cassette_id_label.text = "No Cassette Loaded"
	youtube_panel.hide()
	for child in queue_container.get_children():
		queue_container.remove_child(child)
		child.queue_free()
	item_icon._setup_item(0)
	emit_signal("unload_cassette")	
	
func _on_fastforward_button_pressed():
	var cassette_item = PlayerData._find_item_code(_chosen_item)
	if cassette_item["id"].ends_with("_tape"):
		emit_signal("fastforward")

func _on_rewind_button_pressed():
	var cassette_item = PlayerData._find_item_code(_chosen_item)
	if cassette_item["id"].ends_with("_tape"):
		emit_signal("rewind")
	
func _on_slider_slid(value):
	var volume = linear2db(value)
	emit_signal("slider_slid", volume)	
	
func _on_queue_button_pressed():
	var url = url_input.text
	if url == "" or url == " INVALID URL":
		url = OS.clipboard
	# This is good enough url validating for me. AudioStream also does some basic validating.
	if url.begins_with("http://") or url.begins_with("https://"):
		emit_signal("add_url_to_queue", url)
		url_input.text = ""
		if song_label.text == "":
			song_label.text = "[LOADING SONG]"
		# Create and add a new queue label to the scrollable queue
		var queue_entry = Label.new()
		queue_entry.text = " " + url
		queue_entry.clip_text = true
		queue_entry.size_flags_horizontal = SIZE_EXPAND_FILL
		queue_entry.mouse_filter = Control.MOUSE_FILTER_STOP
		queue_entry.add_stylebox_override("normal", _queue_entry_syle)
		queue_entry.add_font_override("font", _queue_entry_font)
		queue_entry.connect("gui_input", self, "_queue_entry_gui_input", [queue_entry])
		queue_container.add_child(queue_entry)
		_on_play_button_pressed()
	else:
		url_input.text = " INVALID URL"

# This cycles the queue button between "PLAY" / "QUEUE" depending on if songs are queued or not
func _change_queue_button_text(text):
	if queue_button.text != text:
		queue_button.text = text

# Handle right clicking removing songs from the queue
func _queue_entry_gui_input(event, sender):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT and event.pressed:
			var entry_index = sender.get_index()
			if entry_index != 0:
				emit_signal("remove_url_from_queue", entry_index)
				queue_container.remove_child(sender)
				sender.queue_free()
	
func _update_item(items):
	# Item icon code
	if items.size() <= 0: return 
	var item = items[0]
	item_icon._setup_item(item)
	_chosen_item = item
	
	var cassette_item = PlayerData._find_item_code(_chosen_item)
	var cassette_id = ""
	if cassette_item["id"].ends_with("_tape"):
		cassette_id = cassette_item["id"].split(".")[-1]
		emit_signal("load_cassette", cassette_id)
		if cassette_id == "youtube_tape":
			youtube_panel.show()
			cassette_id_label.text = "FishTube"
		else:
			youtube_panel.hide()
			cassette_id_label.text = CozyCassettes.load_cassette_json(cassette_id, CozyCassettes.CASSETTE_DIR, CozyCassettes.TAPE_JSON_DICT)["name"]
		
	elif VintageVideo and cassette_item["id"].ends_with("_vhs"):
		cassette_id = cassette_item["id"].split(".")[-1]
		emit_signal("load_cassette", cassette_id)
		cassette_id_label.text = CozyCassettes.load_cassette_json(cassette_id, VintageVideo.VIDEO_DIR, VintageVideo.TAPE_JSON_DICT)["name"]
	
# Updates the queue list to show the title of the song being played.
# Right now there is no way to do this for songs not playing as metadata can only be pulled
# from the currently loaded song	
func _update_queue_entry(title, index):
	if queue_container.get_child_count() > 0:
		var queue_entry = queue_container.get_child(0)
		queue_entry.text = " " + title + " [NOW PLAYING]"
	
func update_timer(time):
	cassette_timer_label.text = time
		
func update_song(song_title: String):
	song_label.text = song_title
	
func on_track_end():
	song_label.text = ""
	if queue_container.get_child_count() > 0:
		var finished_track = queue_container.get_child(0)
		queue_container.remove_child(finished_track)
		finished_track.queue_free()
