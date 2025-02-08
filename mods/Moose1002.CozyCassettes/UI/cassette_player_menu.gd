extends Control

onready var cassette_id_label = $cassette_id
onready var cassette_timer_label = $timer
onready var item_icon = $item
onready var song_label = $song_title
onready var volume_slider = $volume

onready var CozyCassettes = get_node("/root/Moose1002CozyCassettes")

var _chosen_item = 0

signal load_cassette(cassette_id)
signal unload_cassette()
signal play_cassette(path)
signal stop_cassette()
signal fastforward()
signal rewind()
signal slider_slid(volume)

func _ready():
	PlayerData.connect("_return_item_choice", self, "_update_item")
	item_icon._setup_item(0)

func show(): visible = true
func hide(): visible = false

func _on_close_button_pressed():
	hide()

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
	item_icon._setup_item(0)
	emit_signal("unload_cassette")	
	
func _on_fastforward_button_pressed():
	emit_signal("fastforward")

func _on_rewind_button_pressed():
	emit_signal("rewind")
	
func _on_slider_slid(value):
	var volume = linear2db(value)
	emit_signal("slider_slid", volume)	
	
func _update_item(items):
	# Item icon code
	if items.size() <= 0: return 
	var item = items[0]
	item_icon._setup_item(item)
	_chosen_item = item
	
	var cassette_item = PlayerData._find_item_code(_chosen_item)
	if (not cassette_item["id"].ends_with("tape")): return
	var cassette_id = ""
	cassette_id = cassette_item["id"].split(".")[-1]
	emit_signal("load_cassette", cassette_id)
	cassette_id_label.text = CozyCassettes.load_cassette_json(cassette_id)["name"]
	
func update_timer(time):
	cassette_timer_label.text = time
		
func update_song(song_title: String):
	song_label.text = song_title

