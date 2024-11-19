extends Control

onready var cassette_id_label = $cassette_id
onready var cassette_timer_label = $timer
onready var item_icon = $item

var _chosen_item = 0

signal load_cassette(cassette_id)
signal unload_cassette()
signal play_cassette(path)
signal stop_cassette()
signal fastforward()
signal rewind()

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

func _format_cassette_id(cassette_id: String):
	print(cassette_id)
	var formatted_cassetted_id = cassette_id.trim_suffix("_tape").capitalize()
	return formatted_cassetted_id
	
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
	
func _update_item(items):
	if items.size() <= 0: return 
	var item = items[0]
	item_icon._setup_item(item)
	_chosen_item = item
	
	var cassette_item = PlayerData._find_item_code(_chosen_item)
	var cassette_id = ""
	if (cassette_item["id"].ends_with("tape")):
		cassette_id = cassette_item["id"].split(".")[-1]
	else:
		print("Loaded item is not a tape!")	
		return
		
	emit_signal("load_cassette", cassette_id)
	cassette_id_label.text = _format_cassette_id(cassette_id)
	
func update_timer(time):
	cassette_timer_label.text = time
		
