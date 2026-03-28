extends RefCounted
class_name GridCellData

var coord: Vector2i
var occupant = null
var blocked: bool = false
var zone: int = -1

func _init(p_coord: Vector2i = Vector2i.ZERO, p_zone: int = -1) -> void:
    coord = p_coord
    zone = p_zone
