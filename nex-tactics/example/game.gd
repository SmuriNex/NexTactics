extends Node2D

@onready var saving_label: Label = $CanvasLayer/SavingLabel
@onready var save_agent: SaveAgent = $SaveAgent

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass

func _on_save_agent_start_auto_saving() -> void:
	saving_label.visible = true
	
func _on_save_agent_finish_auto_saving() -> void:
	await get_tree().create_timer(2).timeout
	saving_label.visible = false
