extends Node3D
class_name BoardPresentation3D

const BOARD_BASE_COLOR := Color(0.12, 0.14, 0.16, 1.0)
const PLAYER_TILE_COLOR := Color(0.24, 0.42, 0.78, 1.0)
const ENEMY_TILE_COLOR := Color(0.72, 0.30, 0.32, 1.0)
const NEUTRAL_TILE_COLOR := Color(0.30, 0.30, 0.32, 1.0)
const HIDDEN_TILE_COLOR := Color(0.06, 0.07, 0.08, 1.0)
const GRID_EDGE_COLOR := Color(0.88, 0.90, 0.96, 1.0)
const SELECTED_TILE_COLOR := Color(1.0, 0.92, 0.42, 1.0)
const TARGET_TILE_COLOR := Color(0.42, 0.92, 1.0, 1.0)
const DRAG_VALID_TILE_COLOR := Color(0.36, 0.95, 0.48, 1.0)
const DRAG_INVALID_TILE_COLOR := Color(0.95, 0.42, 0.42, 1.0)

const BOARD_HEIGHT_WORLD := 0.18
const CELL_WORLD_SIZE := 1.22

var current_view_mode: int = GameEnums.BoardViewMode.FULL_BATTLE
var focus_team_side: int = GameEnums.TeamSide.PLAYER
var camera_target: Vector3 = Vector3.ZERO
var selected_coord: Vector2i = Vector2i(-1, -1)
var drag_hover_coord: Vector2i = Vector2i(-1, -1)
var drag_hover_active: bool = false
var drag_hover_valid: bool = false
var target_highlight_coords: Array[Vector2i] = []

var board_root: Node3D
var tiles_root: Node3D
var units_root: Node3D
var board_base_mesh: MeshInstance3D
var world_environment: WorldEnvironment
var key_light: DirectionalLight3D
var fill_light: OmniLight3D
var camera_3d: Camera3D

var tile_materials: Dictionary = {}
var tile_meshes: Dictionary = {}

func _ready() -> void:
	set_process(true)
	_ensure_nodes()
	_build_board_meshes()
	set_view_mode(GameEnums.BoardViewMode.FULL_BATTLE, GameEnums.TeamSide.PLAYER)
	snap_to_mode(GameEnums.BoardViewMode.FULL_BATTLE)

func _process(_delta: float) -> void:
	_refresh_camera_orientation()

func get_units_root() -> Node3D:
	return units_root

func grid_to_world(coord: Vector2i) -> Vector3:
	var board_offset := Vector3(-1.45, 0.0, 0.18)
	var start_x: float = -((BattleConfig.BOARD_WIDTH - 1) * CELL_WORLD_SIZE) * 0.5
	var start_z: float = -((BattleConfig.BOARD_HEIGHT - 1) * CELL_WORLD_SIZE) * 0.5
	return board_offset + Vector3(
		start_x + float(coord.x) * CELL_WORLD_SIZE,
		BOARD_HEIGHT_WORLD * 0.5,
		start_z + float(coord.y) * CELL_WORLD_SIZE
	)

func create_unit_visual(unit_state: BattleUnitState) -> UnitVisual3D:
	var visual := UnitVisual3D.new()
	units_root.add_child(visual)
	visual.setup(unit_state, self)
	return visual

func screen_to_coord(screen_pos: Vector2) -> Vector2i:
	if camera_3d == null:
		return Vector2i(-1, -1)

	var ray_origin: Vector3 = camera_3d.project_ray_origin(screen_pos)
	var ray_normal: Vector3 = camera_3d.project_ray_normal(screen_pos)
	if absf(ray_normal.y) <= 0.0001:
		return Vector2i(-1, -1)

	var plane_y: float = BOARD_HEIGHT_WORLD * 0.5
	var distance: float = (plane_y - ray_origin.y) / ray_normal.y
	if distance < 0.0:
		return Vector2i(-1, -1)

	var world_hit: Vector3 = ray_origin + (ray_normal * distance)
	return world_to_coord(world_hit)

func project_world_to_screen(world_position: Vector3) -> Dictionary:
	if camera_3d == null:
		return {
			"visible": false,
			"screen_position": Vector2.ZERO,
		}
	if camera_3d.is_position_behind(world_position):
		return {
			"visible": false,
			"screen_position": Vector2.ZERO,
		}

	var screen_position: Vector2 = camera_3d.unproject_position(world_position)
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	return {
		"visible": viewport_rect.has_point(screen_position),
		"screen_position": screen_position,
	}

func world_to_coord(world_position: Vector3) -> Vector2i:
	var board_offset := Vector3(-1.45, 0.0, 0.18)
	var start_x: float = -((BattleConfig.BOARD_WIDTH - 1) * CELL_WORLD_SIZE) * 0.5
	var start_z: float = -((BattleConfig.BOARD_HEIGHT - 1) * CELL_WORLD_SIZE) * 0.5
	var min_x: float = board_offset.x + start_x - (CELL_WORLD_SIZE * 0.5)
	var min_z: float = board_offset.z + start_z - (CELL_WORLD_SIZE * 0.5)

	var coord_x: int = int(floor((world_position.x - min_x) / CELL_WORLD_SIZE))
	var coord_y: int = int(floor((world_position.z - min_z) / CELL_WORLD_SIZE))
	if coord_x < 0 or coord_x >= BattleConfig.BOARD_WIDTH:
		return Vector2i(-1, -1)
	if coord_y < 0 or coord_y >= BattleConfig.BOARD_HEIGHT:
		return Vector2i(-1, -1)
	return Vector2i(coord_x, coord_y)

func set_view_mode(view_mode: int, p_focus_team_side: int = GameEnums.TeamSide.PLAYER) -> void:
	current_view_mode = view_mode
	focus_team_side = p_focus_team_side
	_refresh_tile_colors()

func set_selected_coord(coord: Vector2i) -> void:
	selected_coord = coord
	_refresh_tile_colors()

func clear_selection() -> void:
	selected_coord = Vector2i(-1, -1)
	_refresh_tile_colors()

func set_drag_hover(coord: Vector2i, active: bool, valid: bool) -> void:
	drag_hover_coord = coord
	drag_hover_active = active
	drag_hover_valid = valid
	_refresh_tile_colors()

func clear_drag_hover() -> void:
	drag_hover_coord = Vector2i(-1, -1)
	drag_hover_active = false
	drag_hover_valid = false
	_refresh_tile_colors()

func set_target_highlights(coords: Array[Vector2i]) -> void:
	target_highlight_coords = []
	for coord in coords:
		target_highlight_coords.append(coord)
	_refresh_tile_colors()

func clear_target_highlights() -> void:
	target_highlight_coords.clear()
	_refresh_tile_colors()

func snap_to_mode(view_mode: int) -> void:
	set_view_mode(view_mode, focus_team_side)
	if camera_3d == null:
		return
	camera_3d.position = _camera_position_for_mode(view_mode)
	camera_target = _camera_target_for_mode(view_mode)
	_refresh_camera_orientation()

func transition_to_mode(view_mode: int, duration: float = -1.0) -> Tween:
	set_view_mode(view_mode, focus_team_side)
	if camera_3d == null:
		return null

	var resolved_duration: float = duration if duration >= 0.0 else BattleConfig.REVEAL_TRANSITION_SECONDS
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(camera_3d, "position", _camera_position_for_mode(view_mode), resolved_duration)
	tween.parallel().tween_property(self, "camera_target", _camera_target_for_mode(view_mode), resolved_duration)
	return tween

func _ensure_nodes() -> void:
	board_root = get_node_or_null("BoardRoot") as Node3D
	if board_root == null:
		board_root = Node3D.new()
		board_root.name = "BoardRoot"
		add_child(board_root)

	tiles_root = board_root.get_node_or_null("TilesRoot") as Node3D
	if tiles_root == null:
		tiles_root = Node3D.new()
		tiles_root.name = "TilesRoot"
		board_root.add_child(tiles_root)

	units_root = board_root.get_node_or_null("UnitsRoot") as Node3D
	if units_root == null:
		units_root = Node3D.new()
		units_root.name = "UnitsRoot"
		board_root.add_child(units_root)

	board_base_mesh = board_root.get_node_or_null("BoardBase") as MeshInstance3D
	if board_base_mesh == null:
		board_base_mesh = MeshInstance3D.new()
		board_base_mesh.name = "BoardBase"
		board_root.add_child(board_base_mesh)

	world_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null:
		world_environment = WorldEnvironment.new()
		world_environment.name = "WorldEnvironment"
		add_child(world_environment)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.04, 0.05, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.64, 0.66, 0.72, 1.0)
	environment.ambient_light_energy = 1.2
	environment.fog_enabled = false
	world_environment.environment = environment

	key_light = get_node_or_null("KeyLight") as DirectionalLight3D
	if key_light == null:
		key_light = DirectionalLight3D.new()
		key_light.name = "KeyLight"
		add_child(key_light)
	key_light.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	key_light.light_energy = 2.0
	key_light.shadow_enabled = true

	fill_light = get_node_or_null("FillLight") as OmniLight3D
	if fill_light == null:
		fill_light = OmniLight3D.new()
		fill_light.name = "FillLight"
		add_child(fill_light)
	fill_light.position = Vector3(-4.2, 5.4, 4.0)
	fill_light.light_energy = 1.35
	fill_light.omni_range = 18.0

	camera_3d = get_node_or_null("BoardCamera3D") as Camera3D
	if camera_3d == null:
		camera_3d = Camera3D.new()
		camera_3d.name = "BoardCamera3D"
		add_child(camera_3d)
	camera_3d.current = true
	camera_3d.fov = 44.0
	camera_3d.near = 0.1
	camera_3d.far = 80.0

func _build_board_meshes() -> void:
	for child in tiles_root.get_children():
		child.queue_free()
	tile_materials.clear()
	tile_meshes.clear()

	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(
		float(BattleConfig.BOARD_WIDTH) * CELL_WORLD_SIZE + 0.55,
		BOARD_HEIGHT_WORLD,
		float(BattleConfig.BOARD_HEIGHT) * CELL_WORLD_SIZE + 0.55
	)
	board_base_mesh.mesh = board_mesh
	board_base_mesh.position = Vector3(-1.45, -BOARD_HEIGHT_WORLD * 0.5, 0.18)
	board_base_mesh.material_override = _make_surface_material(BOARD_BASE_COLOR, 0.9)

	for y in range(BattleConfig.BOARD_HEIGHT):
		for x in range(BattleConfig.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			var tile_mesh := MeshInstance3D.new()
			tile_mesh.name = "Tile_%d_%d" % [x, y]
			var tile_box := BoxMesh.new()
			tile_box.size = Vector3(CELL_WORLD_SIZE * 0.92, 0.08, CELL_WORLD_SIZE * 0.92)
			tile_mesh.mesh = tile_box
			tile_mesh.position = grid_to_world(coord) + Vector3(0.0, 0.02, 0.0)
			var tile_material := _make_surface_material(_zone_color_for_coord(coord), 0.82)
			tile_mesh.material_override = tile_material
			tiles_root.add_child(tile_mesh)
			tile_materials[coord] = tile_material
			tile_meshes[coord] = tile_mesh

func _refresh_tile_colors() -> void:
	for coord_variant in tile_materials.keys():
		var coord: Vector2i = coord_variant
		var tile_material: StandardMaterial3D = tile_materials[coord]
		if tile_material == null:
			continue
		var resolved_color: Color = _zone_color_for_coord(coord)
		if drag_hover_active and coord == drag_hover_coord:
			resolved_color = DRAG_VALID_TILE_COLOR if drag_hover_valid else DRAG_INVALID_TILE_COLOR
		elif target_highlight_coords.has(coord):
			resolved_color = TARGET_TILE_COLOR
		elif coord == selected_coord:
			resolved_color = SELECTED_TILE_COLOR
		tile_material.albedo_color = resolved_color
		tile_material.emission = resolved_color * 0.12

		var tile_mesh: MeshInstance3D = tile_meshes.get(coord)
		if tile_mesh != null:
			var base_height: float = 0.02
			if drag_hover_active and coord == drag_hover_coord:
				base_height = 0.09
			elif target_highlight_coords.has(coord) or coord == selected_coord:
				base_height = 0.06
			tile_mesh.position = grid_to_world(coord) + Vector3(0.0, base_height, 0.0)

func _zone_color_for_coord(coord: Vector2i) -> Color:
	var zone: int = _zone_for_coord(coord)

	match zone:
		GameEnums.TeamSide.PLAYER:
			return PLAYER_TILE_COLOR
		GameEnums.TeamSide.ENEMY:
			return ENEMY_TILE_COLOR
		_:
			return NEUTRAL_TILE_COLOR

func _zone_for_coord(coord: Vector2i) -> int:
	if coord.y < BattleConfig.ENEMY_ROWS:
		return GameEnums.TeamSide.ENEMY
	if coord.y >= BattleConfig.BOARD_HEIGHT - BattleConfig.PLAYER_ROWS:
		return GameEnums.TeamSide.PLAYER
	return -1

func _camera_position_for_mode(view_mode: int) -> Vector3:
	if view_mode == GameEnums.BoardViewMode.SELF_ONLY:
		return Vector3(-1.45, 9.5, 8.8)
	return Vector3(-1.45, 9.8, 9.1)

func _camera_target_for_mode(view_mode: int) -> Vector3:
	if view_mode == GameEnums.BoardViewMode.SELF_ONLY:
		return Vector3(-1.45, 0.0, 0.55)
	return Vector3(-1.45, 0.0, 0.18)

func _refresh_camera_orientation() -> void:
	if camera_3d == null:
		return
	camera_3d.look_at(camera_target, Vector3.UP)

func _make_surface_material(albedo: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = 0.05
	material.emission_enabled = true
	material.emission = GRID_EDGE_COLOR * 0.04
	return material
