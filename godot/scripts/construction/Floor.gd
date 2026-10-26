class_name Floor
extends StaticBody3D

## Piso base para las habitaciones o espacios expositivos de la galería de arte.
## Incluye StaticBody3D y CollisionShape3D para permitir la navegación y colisiones en Modo Visualizar.

@export var floor_width: float = 40.0
@export var floor_depth: float = 40.0
@export var floor_thickness: float = 0.2

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var floor_material: StandardMaterial3D


func _ready() -> void:
	_setup_material()
	update_floor()


func _setup_material() -> void:
	floor_material = StandardMaterial3D.new()
	# Tono gris cálido/cemento pulido para piso de galería
	floor_material.albedo_color = Color(0.85, 0.84, 0.82)
	floor_material.roughness = 0.4
	floor_material.metallic = 0.05
	floor_material.uv1_scale = Vector3(floor_width * 0.5, floor_depth * 0.5, 1.0)


func setup_dimensions(width: float, depth: float, thickness: float = 0.2) -> void:
	floor_width = width
	floor_depth = depth
	floor_thickness = thickness
	update_floor()


func update_floor() -> void:
	# Centrar el piso de modo que la superficie superior esté exactamente en Y = 0
	var half_thickness := floor_thickness * 0.5
	
	if mesh_instance != null:
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(floor_width, floor_thickness, floor_depth)
		mesh_instance.mesh = box_mesh
		mesh_instance.position = Vector3(0.0, -half_thickness, 0.0)
		
		if floor_material == null:
			_setup_material()
		mesh_instance.material_override = floor_material
	
	if collision_shape != null:
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(floor_width, floor_thickness, floor_depth)
		collision_shape.shape = box_shape
		collision_shape.position = Vector3(0.0, -half_thickness, 0.0)


func to_dict() -> Dictionary:
	return {
		"width": floor_width,
		"depth": floor_depth,
		"thickness": floor_thickness
	}


func from_dict(data: Dictionary) -> void:
	if data.has("width"):
		floor_width = float(data["width"])
	if data.has("depth"):
		floor_depth = float(data["depth"])
	if data.has("thickness"):
		floor_thickness = float(data["thickness"])
	update_floor()
