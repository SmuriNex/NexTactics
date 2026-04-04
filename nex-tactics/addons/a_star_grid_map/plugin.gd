@tool
extends EditorPlugin

func get_plugin_path() -> String:
	return get_script().resource_path.get_base_dir()

func _enter_tree():
	add_custom_type("AStarGridMap2D", "Node2D", load(get_plugin_path() + "/nodes/a_star_grid_map_2d.gd"), load(get_plugin_path() + "/assets/a_star_grid_map_2d.svg"))

func _exit_tree():
	remove_custom_type("AStarGridMap2D")
