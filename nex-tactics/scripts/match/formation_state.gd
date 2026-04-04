extends RefCounted
class_name FormationState

var unit_entries: Dictionary = {}
var _next_order_index: int = 0

func clear() -> void:
	unit_entries.clear()
	_next_order_index = 0

func register_unit(
	unit_id: String,
	unit_path: String,
	home_coord: Vector2i,
	is_master: bool = false,
	order_index: int = -1
) -> void:
	var resolved_unit_id: String = str(unit_id)
	if resolved_unit_id.is_empty():
		return

	var resolved_order_index: int = order_index
	if resolved_order_index < 0:
		if unit_entries.has(resolved_unit_id):
			resolved_order_index = int(unit_entries[resolved_unit_id].get("order_index", _next_order_index))
		else:
			resolved_order_index = _next_order_index
	if is_master:
		var stale_master_ids: Array[String] = []
		for existing_unit_id in unit_entries.keys():
			if str(existing_unit_id) == resolved_unit_id:
				continue
			var existing_entry: Dictionary = unit_entries[existing_unit_id]
			if bool(existing_entry.get("is_master", false)):
				stale_master_ids.append(str(existing_unit_id))
		for stale_master_id in stale_master_ids:
			unit_entries.erase(stale_master_id)
	unit_entries[resolved_unit_id] = {
		"unit_id": resolved_unit_id,
		"unit_path": str(unit_path),
		"home_coord": home_coord,
		"is_master": is_master,
		"order_index": resolved_order_index,
	}
	_next_order_index = maxi(_next_order_index, resolved_order_index + 1)

func update_unit_coord(unit_id: String, home_coord: Vector2i) -> void:
	var resolved_unit_id: String = str(unit_id)
	if resolved_unit_id.is_empty() or not unit_entries.has(resolved_unit_id):
		return
	var entry: Dictionary = unit_entries[resolved_unit_id]
	entry["home_coord"] = home_coord
	unit_entries[resolved_unit_id] = entry

func remove_unit(unit_id: String) -> void:
	var resolved_unit_id: String = str(unit_id)
	if resolved_unit_id.is_empty():
		return
	unit_entries.erase(resolved_unit_id)

func has_unit(unit_id: String) -> bool:
	return unit_entries.has(str(unit_id))

func get_unit_entry(unit_id: String) -> Dictionary:
	var resolved_unit_id: String = str(unit_id)
	if not unit_entries.has(resolved_unit_id):
		return {}
	return (unit_entries[resolved_unit_id] as Dictionary).duplicate(true)

func get_unit_coord(unit_id: String, fallback_coord: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	var entry: Dictionary = get_unit_entry(unit_id)
	if entry.is_empty():
		return fallback_coord
	return entry.get("home_coord", fallback_coord)

func get_master_entry() -> Dictionary:
	for entry_variant in unit_entries.values():
		var entry: Dictionary = entry_variant
		if bool(entry.get("is_master", false)):
			return entry.duplicate(true)
	return {}

func get_master_coord(fallback_coord: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	var entry: Dictionary = get_master_entry()
	if entry.is_empty():
		return fallback_coord
	return entry.get("home_coord", fallback_coord)

func get_ordered_entries(include_master: bool = true) -> Array[Dictionary]:
	var ordered_entries: Array[Dictionary] = []
	for entry_variant in unit_entries.values():
		var entry: Dictionary = entry_variant
		if not include_master and bool(entry.get("is_master", false)):
			continue
		ordered_entries.append(entry.duplicate(true))
	ordered_entries.sort_custom(_sort_entries)
	return ordered_entries

func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	var master_a: bool = bool(a.get("is_master", false))
	var master_b: bool = bool(b.get("is_master", false))
	if master_a != master_b:
		return master_a

	var order_a: int = int(a.get("order_index", 0))
	var order_b: int = int(b.get("order_index", 0))
	if order_a != order_b:
		return order_a < order_b

	var coord_a: Vector2i = a.get("home_coord", Vector2i(-1, -1))
	var coord_b: Vector2i = b.get("home_coord", Vector2i(-1, -1))
	if coord_a.y != coord_b.y:
		return coord_a.y < coord_b.y
	if coord_a.x != coord_b.x:
		return coord_a.x < coord_b.x
	return str(a.get("unit_id", "")) < str(b.get("unit_id", ""))
