extends Control
class_name SaveSlot

signal Load(slot : SaveFile)
signal Delete(slot : SaveFile)

@export var saveSlot : SaveFile
@onready var name_label: Label = $HBoxContainer/VBoxContainer/NameGroup/NameLabel
@onready var date_label: Label = $HBoxContainer/VBoxContainer/DateGroup/DateLabel
@onready var game_time_label: Label = $HBoxContainer/VBoxContainer/GameTimeGroup/GameTimeLabel
@onready var slot_image: TextureRect = $HBoxContainer/ImageMargin/SlotImage

func _ready() -> void:
	LoadData()

func LoadData():	
	name_label.text = saveSlot.Name
	date_label.text = Time.get_datetime_string_from_datetime_dict(saveSlot.DateTime, true) 	
	game_time_label.text = FormatGameTime()
	if saveSlot.MetaData.has("image"):
		slot_image.texture = load(saveSlot.MetaData["image"])

func _on_load_game_pressed() -> void:
	Load.emit(saveSlot)

func _on_delete_slot_pressed() -> void:
	Delete.emit(saveSlot)
	
func FormatGameTime() -> String:
	var result = ""
	var fullSeconds = saveSlot.GameTime
	var hours = fullSeconds / 3600
	fullSeconds = fullSeconds - hours * 3600
	var minutes = fullSeconds / 60
	fullSeconds = fullSeconds - minutes * 60
	var seconds = fullSeconds
	if hours < 10:
		result = result + "0" + str(hours) + ":"
	else:
		result = result + str(hours) + ":"
	if minutes < 10:
		result = result + "0" + str(minutes) + ":"
	else:
		result = result + str(minutes) + ":"
	if seconds < 10:
		result = result + "0" + str(seconds)
	else:
		result = result + str(seconds)		
	return result
