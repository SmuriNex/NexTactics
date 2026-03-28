extends Node3D
class_name UnitVisual3D

const PLAYER_COLOR := Color(0.26, 0.62, 0.98, 1.0)
const ENEMY_COLOR := Color(0.94, 0.34, 0.36, 1.0)
const MASTER_COLOR := Color(0.96, 0.84, 0.34, 1.0)
const SUPPORT_DETAIL_COLOR := Color(0.60, 0.92, 1.0, 1.0)
const DAMAGE_FLASH_COLOR := Color(1.0, 0.78, 0.78, 1.0)
const HEAL_FLASH_COLOR := Color(0.70, 1.0, 0.72, 1.0)
const BUFF_FLASH_COLOR := Color(0.74, 0.92, 1.0, 1.0)
const SKILL_FLASH_COLOR := Color(1.0, 0.94, 0.62, 1.0)
const SELECTION_RING_COLOR := Color(1.0, 0.96, 0.48, 0.95)

var state: BattleUnitState
var board_presentation: BoardPresentation3D
var body_mesh: MeshInstance3D
var top_mesh: MeshInstance3D
var detail_mesh: MeshInstance3D
var selection_ring: MeshInstance3D

var body_material: StandardMaterial3D
var top_material: StandardMaterial3D
var detail_material: StandardMaterial3D
var ring_material: StandardMaterial3D

var base_body_color: Color = PLAYER_COLOR
var base_top_color: Color = MASTER_COLOR
var base_detail_color: Color = SUPPORT_DETAIL_COLOR
var is_selected: bool = false
var death_started: bool = false

func setup(p_state: BattleUnitState, p_board_presentation: BoardPresentation3D) -> UnitVisual3D:
	state = p_state
	board_presentation = p_board_presentation
	_build_visual_nodes()
	refresh_from_state()
	move_to_coord(state.coord, false)
	return self

func move_to_coord(coord: Vector2i, animate: bool = true) -> void:
	if board_presentation == null:
		return
	var target_position: Vector3 = board_presentation.grid_to_world(coord)
	if animate:
		var move_tween := create_tween()
		move_tween.set_trans(Tween.TRANS_SINE)
		move_tween.set_ease(Tween.EASE_IN_OUT)
		move_tween.tween_property(self, "position", target_position, 0.10)
	else:
		position = target_position

func get_overlay_anchor_world_position() -> Vector3:
	var body_dimensions: Dictionary = _body_dimensions()
	var body_height: float = float(body_dimensions.get("height", 0.86))
	return global_position + Vector3(0.0, body_height * 0.64, 0.0)

func get_overlay_base_world_position() -> Vector3:
	var body_dimensions: Dictionary = _body_dimensions()
	var body_height: float = float(body_dimensions.get("height", 0.86))
	return global_position + Vector3(0.0, body_height * 0.18, 0.0)

func get_overlay_top_world_position() -> Vector3:
	var body_dimensions: Dictionary = _body_dimensions()
	var body_height: float = float(body_dimensions.get("height", 0.86))
	var top_height: float = 0.12 if state != null and state.is_master else 0.08
	return global_position + Vector3(0.0, body_height + top_height, 0.0)

func refresh_from_state() -> void:
	if state == null:
		return
	base_body_color = _body_color()
	base_top_color = MASTER_COLOR if state.is_master else base_body_color.lightened(0.16)
	base_detail_color = SUPPORT_DETAIL_COLOR if state.is_support_unit() else base_body_color.darkened(0.24)

	if state.is_dead():
		base_body_color = base_body_color.darkened(0.55)
		base_top_color = base_top_color.darkened(0.48)
		base_detail_color = base_detail_color.darkened(0.5)

	_apply_material_colors(base_body_color, base_top_color, base_detail_color)
	_update_selection_ring()

func on_damage() -> void:
	refresh_from_state()
	_flash_visual(DAMAGE_FLASH_COLOR, 1.12)

func on_heal() -> void:
	refresh_from_state()
	_flash_visual(HEAL_FLASH_COLOR, 1.08)

func on_buff() -> void:
	refresh_from_state()
	_flash_visual(BUFF_FLASH_COLOR, 1.08)

func on_skill_cast() -> void:
	_flash_visual(SKILL_FLASH_COLOR, 1.16)

func on_death() -> void:
	if death_started:
		return
	death_started = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector3(0.18, 0.06, 0.18), 0.14)
	tween.parallel().tween_property(body_material, "albedo_color", Color(base_body_color.r, base_body_color.g, base_body_color.b, 0.0), 0.14)
	tween.parallel().tween_property(top_material, "albedo_color", Color(base_top_color.r, base_top_color.g, base_top_color.b, 0.0), 0.14)
	if detail_material != null:
		tween.parallel().tween_property(detail_material, "albedo_color", Color(base_detail_color.r, base_detail_color.g, base_detail_color.b, 0.0), 0.14)
	if ring_material != null:
		tween.parallel().tween_property(ring_material, "albedo_color", Color(SELECTION_RING_COLOR.r, SELECTION_RING_COLOR.g, SELECTION_RING_COLOR.b, 0.0), 0.14)
	tween.finished.connect(queue_free)

func set_selected(value: bool) -> void:
	is_selected = value
	_update_selection_ring()

func _build_visual_nodes() -> void:
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	add_child(body_mesh)

	top_mesh = MeshInstance3D.new()
	top_mesh.name = "TopMesh"
	add_child(top_mesh)

	selection_ring = MeshInstance3D.new()
	selection_ring.name = "SelectionRing"
	add_child(selection_ring)

	body_material = _make_material(base_body_color)
	top_material = _make_material(base_top_color)
	ring_material = _make_material(SELECTION_RING_COLOR)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.emission_enabled = true
	ring_material.emission = SELECTION_RING_COLOR

	var body_dimensions: Dictionary = _body_dimensions()
	var body_radius: float = float(body_dimensions.get("radius", 0.34))
	var body_height: float = float(body_dimensions.get("height", 0.86))

	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = body_radius
	cylinder_mesh.bottom_radius = body_radius
	cylinder_mesh.height = body_height
	cylinder_mesh.radial_segments = 24
	body_mesh.mesh = cylinder_mesh
	body_mesh.material_override = body_material
	body_mesh.position = Vector3(0.0, body_height * 0.5, 0.0)

	var top_mesh_resource := CylinderMesh.new()
	top_mesh_resource.top_radius = body_radius * 0.92
	top_mesh_resource.bottom_radius = body_radius * 0.98
	top_mesh_resource.height = 0.12 if state != null and state.is_master else 0.08
	top_mesh_resource.radial_segments = 24
	top_mesh.mesh = top_mesh_resource
	top_mesh.material_override = top_material
	top_mesh.position = Vector3(0.0, body_height + top_mesh_resource.height * 0.5, 0.0)

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = body_radius * 1.22
	ring_mesh.bottom_radius = body_radius * 1.22
	ring_mesh.height = 0.04
	ring_mesh.radial_segments = 24
	selection_ring.mesh = ring_mesh
	selection_ring.material_override = ring_material
	selection_ring.position = Vector3(0.0, 0.03, 0.0)

	if state != null and state.is_support_unit():
		detail_mesh = MeshInstance3D.new()
		detail_mesh.name = "SupportDetail"
		add_child(detail_mesh)
		detail_material = _make_material(base_detail_color)
		var orb_mesh := SphereMesh.new()
		orb_mesh.radius = body_radius * 0.36
		orb_mesh.height = body_radius * 0.72
		detail_mesh.mesh = orb_mesh
		detail_mesh.material_override = detail_material
		detail_mesh.position = Vector3(0.0, body_height + 0.28, 0.0)
	elif state != null and state.is_master:
		detail_mesh = MeshInstance3D.new()
		detail_mesh.name = "MasterDetail"
		add_child(detail_mesh)
		detail_material = _make_material(MASTER_COLOR.lightened(0.1))
		var halo_mesh := CylinderMesh.new()
		halo_mesh.top_radius = body_radius * 1.08
		halo_mesh.bottom_radius = body_radius * 1.08
		halo_mesh.height = 0.07
		halo_mesh.radial_segments = 24
		detail_mesh.mesh = halo_mesh
		detail_mesh.material_override = detail_material
		detail_mesh.position = Vector3(0.0, body_height * 0.54, 0.0)

	_update_selection_ring()

func _body_dimensions() -> Dictionary:
	if state == null:
		return {"radius": 0.34, "height": 0.86}
	if state.is_master:
		return {"radius": 0.44, "height": 1.34}
	if state.is_tank_unit():
		return {"radius": 0.42, "height": 0.96}
	if state.is_support_unit():
		return {"radius": 0.34, "height": 0.84}
	if state.is_sniper_unit():
		return {"radius": 0.24, "height": 0.78}
	return {"radius": 0.31, "height": 0.82}

func _body_color() -> Color:
	if state != null and state.is_master:
		return MASTER_COLOR if state.team_side == GameEnums.TeamSide.PLAYER else ENEMY_COLOR.darkened(0.08)
	if state != null and state.team_side == GameEnums.TeamSide.ENEMY:
		return ENEMY_COLOR
	return PLAYER_COLOR

func _apply_material_colors(body_color: Color, top_color: Color, detail_color: Color) -> void:
	if body_material != null:
		body_material.albedo_color = body_color
		body_material.emission = body_color * 0.08
	if top_material != null:
		top_material.albedo_color = top_color
		top_material.emission = top_color * 0.10
	if detail_material != null:
		detail_material.albedo_color = detail_color
		detail_material.emission = detail_color * 0.12

func _flash_visual(flash_color: Color, scale_multiplier: float) -> void:
	if death_started:
		return
	scale = Vector3(scale_multiplier, scale_multiplier, scale_multiplier)
	_apply_material_colors(flash_color, flash_color.lightened(0.08), flash_color)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector3.ONE, 0.12)
	tween.tween_callback(refresh_from_state)

func _update_selection_ring() -> void:
	if selection_ring == null:
		return
	selection_ring.visible = is_selected and not death_started
	if ring_material != null:
		ring_material.albedo_color = Color(
			SELECTION_RING_COLOR.r,
			SELECTION_RING_COLOR.g,
			SELECTION_RING_COLOR.b,
			0.95 if selection_ring.visible else 0.0
		)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.metallic = 0.08
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color * 0.08
	return material
