extends Node2D

@export var region : Rect2i = Rect2i(0, 0, 32, 32)
@export var cell_size : Vector2i = Vector2i(16, 16)
@export var diagonal_mode : AStarGrid2D.DiagonalMode
@export var exclude_tilemaps : Array[TileMapLayer]
@export var dynamic_solid_groups : Array[StringName]
## Settings for displaying information when Debug -> Visible Navigation is enabled.
@export_group("Debugging", "debug")
@export var debug_cell_texture : Texture2D = preload("uid://dawcvbhuuni8n")
@export var debug_update_time : float = 0
@export var debug_normal_color : Color = Color.WHITE
@export var debug_static_solid_color : Color = Color.RED
@export var debug_dynamic_solid_color : Color = Color.ORANGE
@export var debug_path_color : Color = Color.GREEN
var astar : AStarGrid2D
var current_debug_update_time : float = 0
var static_solid_points = []
var dynamic_solid_nodes = {}
var last_path : Array

func set_path_length(point_path: Array, max_distance: int) -> Array:
	if max_distance < 0:
		return point_path
	point_path.resize(min(point_path.size(), max_distance))
	return point_path

func exclude_tilemap(tilemap : TileMapLayer):
	var x_size = region.size.x
	var y_size = region.size.y
	for x in range(x_size):
		for y in range(y_size):
			var astar_vector = Vector2i(x, y) + region.position
			var ratio = Vector2(cell_size) / Vector2(tilemap.tile_set.tile_size)
			var x_total = floor(astar_vector.x * ratio.x)
			var y_total = floor(astar_vector.y * ratio.y)
			var coord2i = Vector2i(x_total, y_total)
			var results = tilemap.get_cell_source_id(coord2i)
			if results > -1:
				astar.set_point_solid(astar_vector, true)
				static_solid_points.append(astar_vector)

func _process_debug(delta):
	if not get_tree().debug_navigation_hint:
		return
	if debug_update_time <= 0:
		return
	current_debug_update_time += delta
	if current_debug_update_time < debug_update_time:
		return
	current_debug_update_time = debug_update_time - current_debug_update_time
	queue_redraw()

func _process(delta):
	_process_debug(delta)

func _ready_astargrid():
	astar = AStarGrid2D.new()
	astar.region = region
	astar.cell_size = Vector2(cell_size)
	astar.diagonal_mode = diagonal_mode
	astar.jumping_enabled = true
	astar.update()

func _ready_wall_points():
	for tilemap in exclude_tilemaps:
		exclude_tilemap(tilemap)

func _connect_dynamic_node(node : Node2D):
	if node.has_signal(&"colliders_changed") and not node.is_connected(&"colliders_changed", _refresh_node_solid_points):
		node.connect(&"colliders_changed", _refresh_node_solid_points.bind(node))

func _ready_dynamic_nodes():
	for group_name in dynamic_solid_groups:
		var group_nodes = get_tree().get_nodes_in_group(group_name)
		for node in group_nodes:
			_connect_dynamic_node(node)
			_refresh_node_solid_points(node)

func _ready() -> void:
	exclude_tilemaps = exclude_tilemaps
	_ready_astargrid()
	_ready_wall_points()
	_ready_dynamic_nodes()

func _draw():
	if not get_tree().debug_navigation_hint:
		return
	var dynamic_points = get_all_dynamic_points()
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var draw_coords = Vector2(x, y) * Vector2(cell_size) - debug_cell_texture.get_size()/2
			draw_coords += Vector2(get_half_cell_size())
			if Vector2i(x, y) in dynamic_points:
				draw_texture(debug_cell_texture, draw_coords, debug_dynamic_solid_color)
			elif Vector2i(x, y) in static_solid_points:
				draw_texture(debug_cell_texture, draw_coords, debug_static_solid_color)
			else:
				draw_texture(debug_cell_texture, draw_coords, debug_normal_color)
	if last_path.is_empty(): return
	var prev_point : Vector2
	for point in last_path:
		if not prev_point:
			prev_point = point
			continue
		draw_line(prev_point, point, debug_path_color, 1.0)
		prev_point = point

func _refresh_node_solid_points(node : Node):
	for child in node.get_children():
		if child is CollisionShape2D:
			var shape : Shape2D = child.shape
			var shape_rect := shape.get_rect()
			var blocking = !child.disabled
			dynamic_solid_nodes[node] = []
			if not blocking: continue
			shape_rect.position += child.global_position 
			var start_point = round(shape_rect.position / Vector2(cell_size))
			var end_point = round(shape_rect.end / Vector2(cell_size))
			for y in range(start_point.y, end_point.y):
				for x in range(start_point.x, end_point.x):
					var point = Vector2i(x, y)
					if point in static_solid_points or not astar.is_in_boundsv(point): 
						continue
					dynamic_solid_nodes[node].append(point)

func set_points_solid(points : Array, solid : bool = true) -> void:
	for point_vector in points:
		point_vector = Vector2i(point_vector)
		if astar.is_in_boundsv(point_vector):
			astar.set_point_solid(point_vector, solid)

func get_all_dynamic_points() -> Array[Vector2i]:
	var return_points : Array[Vector2i]
	for node in dynamic_solid_nodes:
		var points : Array = dynamic_solid_nodes[node]
		for point in points:
			if point is Vector2i and point not in return_points:
				return_points.append(point)
	return return_points

func set_all_dynamic_points_solid(solid : bool = true):
	set_points_solid(get_all_dynamic_points(), solid)

func get_astar_path(start_cell: Vector2, end_cell: Vector2, max_distance := -1) -> Array:
	if not astar.is_in_boundsv(start_cell) or not astar.is_in_boundsv(end_cell):
		return []
	set_all_dynamic_points_solid(true)
	var astar_path := astar.get_point_path(start_cell, end_cell)
	set_all_dynamic_points_solid(false)
	return set_path_length(astar_path, max_distance)

func get_astar_path_avoiding_points(start_cell: Vector2, end_cell: Vector2, avoid_cells : Array = [], max_distance := -1) -> Array:
	set_points_solid(avoid_cells)
	var astar_path := get_astar_path(start_cell, end_cell, max_distance)
	set_points_solid(avoid_cells, false)
	return astar_path
	
func get_half_cell_size() -> Vector2i:
	@warning_ignore("integer_division")
	return cell_size / 2

func get_nearest_tile_position(check_position : Vector2) -> Vector2i :
	return Vector2i(round(check_position / Vector2(cell_size)))

func add_half_cell_to_path(path : Array) -> Array[Vector2]:
	var return_path : Array[Vector2] = []
	for cell_vector in path:
		return_path.append(cell_vector + Vector2(get_half_cell_size()))
	return return_path

func get_world_path_avoiding_points(start_position: Vector2, end_position: Vector2, avoid_positions : Array = [], max_distance := -1) -> Array:
	var start_cell := get_nearest_tile_position(start_position - Vector2(get_half_cell_size()))
	var end_cell := get_nearest_tile_position(end_position - Vector2(get_half_cell_size()))
	var avoid_cells := []
	for avoid_position in avoid_positions:
		avoid_cells.append(get_nearest_tile_position(avoid_position))
	var return_path = get_astar_path_avoiding_points(start_cell, end_cell, avoid_cells, max_distance)
	last_path = add_half_cell_to_path(return_path)
	return last_path

func get_tiles_within_radius(center : Vector2i, radius : int, blocked_positions : Array = [], exclude_center : bool = true) -> Array[Vector2i]:
	var previous_radius_tiles : Array[Vector2i] = [Vector2i.ZERO]
	var all_tiles : Array[Vector2i] = previous_radius_tiles.duplicate()
	var current_radius : int = 0
	var adjacent_tiles : Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var blocked_cells : Array[Vector2i] = []
	for blocked_position in blocked_positions:
		blocked_cells.append(get_nearest_tile_position(blocked_position))
	blocked_cells.append_array(static_solid_points)
	blocked_cells.append_array(get_all_dynamic_points())
	while (current_radius < radius):
		var current_radius_tiles : Array[Vector2i] = []
		for tile in previous_radius_tiles:
			for adjacent_tile in adjacent_tiles:
				var new_tile = tile + adjacent_tile
				if new_tile in all_tiles: continue
				if new_tile + center in blocked_cells: continue
				if new_tile in current_radius_tiles: continue
				current_radius_tiles.append(new_tile)
		all_tiles += current_radius_tiles
		previous_radius_tiles = current_radius_tiles
		current_radius += 1
	if exclude_center:
		all_tiles.erase(Vector2i.ZERO)
	return all_tiles
