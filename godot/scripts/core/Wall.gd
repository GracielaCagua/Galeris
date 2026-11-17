extends StaticBody3D
class_name GalleryWall

@export var wall_id := ""
@export var width := 4.0
@export var height := 3.0
@export var thickness := 0.2

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D

func _ready() -> void:
	add_to_group("persistible")
	add_to_group("pared")
	add_to_group("editor_tool")
	_build_geometry()
	_sync_geometry()

func configure(new_id: String, new_width: float = 4.0, new_height: float = 3.0, new_thickness: float = 0.2) -> void:
	wall_id = new_id
	width = maxf(new_width, 0.1)
	height = maxf(new_height, 0.1)
	thickness = maxf(new_thickness, 0.05)
	if is_inside_tree():
		_sync_geometry()

func set_dimensions(new_width: float, new_height: float) -> void:
	width = maxf(new_width, 0.1)
	height = maxf(new_height, 0.1)
	_sync_geometry()

func _build_geometry() -> void:
	if _mesh_instance != null:
		return
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Malla"
	add_child(_mesh_instance)
	_collision = CollisionShape3D.new()
	_collision.name = "Colision"
	add_child(_collision)

func _sync_geometry() -> void:
	if _mesh_instance == null:
		return
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(width, height, thickness)
	_mesh_instance.mesh = box_mesh
	_mesh_instance.position = Vector3(0, height * 0.5, 0)
	var box_shape := BoxShape3D.new()
	box_shape.size = box_mesh.size
	_collision.shape = box_shape
	_collision.position = Vector3(0, height * 0.5, 0)

func serialize() -> Dictionary:
	var half := Vector3(width * 0.5, 0, 0)
	var start := global_position - global_basis * half
	var finish := global_position + global_basis * half
	return {
		"id": wall_id,
		"inicio": [start.x, start.z],
		"fin": [finish.x, finish.z],
		"alto": height,
		"grosor": thickness
	}

func deserialize(data: Dictionary) -> void:
	if not data.has("id") or not data.has("inicio") or not data.has("fin") or not data.has("alto") or not data.has("grosor"):
		push_error("Datos incompletos para pared")
		return
	var start: Array = data["inicio"]
	var finish: Array = data["fin"]
	if start.size() < 2 or finish.size() < 2:
		push_error("Los extremos de la pared deben contener [x, z]")
		return
	wall_id = str(data["id"])
	var a := Vector3(float(start[0]), 0, float(start[1]))
	var b := Vector3(float(finish[0]), 0, float(finish[1]))
	global_position = (a + b) * 0.5
	width = maxf(a.distance_to(b), 0.1)
	height = maxf(float(data["alto"]), 0.1)
	thickness = maxf(float(data["grosor"]), 0.05)
	rotation.y = atan2(-(b - a).z, (b - a).x)
	_sync_geometry()
