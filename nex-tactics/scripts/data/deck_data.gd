extends Resource
class_name DeckData

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var master_data_path: String = ""
@export var unit_pool_paths: PackedStringArray = PackedStringArray()
@export var card_pool_paths: PackedStringArray = PackedStringArray()
