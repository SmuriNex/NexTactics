extends Control

@onready var slots_stack: VBoxContainer = $Scroll/SlotsStack
@onready var new_game_name: TextEdit = $HBoxContainer/NewGameName

var saveSlots : Array[SaveFile] = []

func _ready() -> void:
	LoadSlots()
	
func LoadSlots():
	saveSlots = SaveService.GetSlots()
	for child in slots_stack.get_children():
		child.queue_free()
	for slot in saveSlots:
		var slotView = load("res://example/SaveSlot.tscn").instantiate() as SaveSlot
		slotView.saveSlot = slot
		slotView.Load.connect(LoadGame)
		slotView.Delete.connect(DeleteSlot)
		slots_stack.add_child(slotView)

func LoadGame(slot : SaveFile):
	SaveService.LoadGame(slot.SlotId)
	get_tree().change_scene_to_file(SaveService.CurrentLoadedSlot.CurrentSceneId)	
	
func DeleteSlot(slot : SaveFile):
	SaveService.DeleteSlot(slot.SlotId)
	LoadSlots()
	
func NewGame():
	var name = new_game_name.text.strip_edges()	
	if name.is_empty():
		return	
	if saveSlots.any(func(item : SaveFile): return item.Name == name):
		return	
	var slotId = name.replace(" ", "_")
	SaveService.NewSlot(slotId, name, "res://example/Game.tscn")
	LoadSlots()

func _on_new_game_pressed() -> void:
	NewGame()
