class_name Wall
extends StaticBody3D

## Representa una pared individual creada en el Modo Crear.
## Cuenta con StaticBody3D y CollisionShape3D para soporte completo de colisiones en Modo Visualizar.

signal wall_clicked(wall: Wall)

@export var wall_id: String = ""
@export var start_point: Vector3 = Vector3.ZERO
@export var end_point: Vector3 = Vector3.FORWARD
@export var wall_height: float = 3.0
@export var wall_thickness: float = 0.2

var is_selected: bool = false:
	set = set_selected

var is_preview: bool = false:
	set = set_is_preview

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var default_material: StandardMaterial3D
var selected_material: StandardMaterial3D
var preview_material: StandardMaterial3D


func _ready() -> void:
	if wall_id.is_empty():
		wall_id = "wall_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
	
	_setup_materials()
	input_ray_pickable = true
	input_event.connect(_on_input_event)
	update_geometry()


func _setup_materials() -> void:
	# Material normal para la galería de arte (blanco/neutro)
	default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color(0.92, 0.92, 0.94)
	default_material.roughness = 0.85
	
	# Material cuando la pared está seleccionada en Modo Crear
	selected_material = StandardMaterial3D.new()
	selected_material.albedo_color = Color(0.2, 0.6, 1.0)
	selected_material.emission_enabled = true
	selected_material.emission = Color(0.1, 0.4, 0.8)
	selected_material.emission_energy_multiplier = 0.6
	
	# Material semitransparente para vista previa durante la construcción
	preview_material = StandardMaterial3D.new()
	preview_material.albedo_color = Color(0.2, 0.8, 0.4, 0.5)
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func setup(p_start: Vector3, p_end: Vector3, p_height: float = 3.0, p_thickness: float = 0.2) -> void:
	start_point = p_start
	end_point = p_end
	wall_height = p_height
	wall_thickness = p_thickness
	update_geometry()


func update_geometry() -> void:
	var diff := end_point - start_point
	var length := diff.length()
	
	if length < 0.01:
		length = 0.01
	
	# Posición central de la pared en X y Z, y elevada a la mitad de su altura en Y
	var center := (start_point + end_point) * 0.5
	center.y = start_point.y + (wall_height * 0.5)
	global_position = center
	
	# Orientación: rotar para que coincida con la dirección start -> end
	if diff.length_squared() > 0.0001:
		var dir := diff.normalized()
		var forward := Vector3(dir.x, 0.0, dir.z).normalized()
		if forward.length_squared() > 0.0001:
			var angle := atan2(forward.x, forward.z)
			rotation = Vector3(0.0, angle, 0.0)
	
	# Actualizar Mesh
	if mesh_instance != null:
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(wall_thickness, wall_height, length)
		mesh_instance.mesh = box_mesh
		_update_mesh_material()
	
	# Actualizar Colisión
	if collision_shape != null:
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(wall_thickness, wall_height, length)
		collision_shape.shape = box_shape
		collision_shape.disabled = is_preview


func set_selected(val: bool) -> void:
	is_selected = val
	_update_mesh_material()


func set_is_preview(val: bool) -> void:
	is_preview = val
	if collision_shape != null:
		collision_shape.disabled = is_preview
	_update_mesh_material()


func _update_mesh_material() -> void:
	if mesh_instance == null:
		return
		
	if default_material == null:
		_setup_materials()
		
	if is_preview:
		mesh_instance.material_override = preview_material
	elif is_selected:
		mesh_instance.material_override = selected_material
	else:
		mesh_instance.material_override = default_material


func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if is_preview:
		return
		
	# Solo interactivo si estamos en Modo Crear
	if AppManager.puede_editar() and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			wall_clicked.emit(self)


func move_by(offset: Vector3) -> void:
	start_point += offset
	end_point += offset
	update_geometry()


func to_dict() -> Dictionary:
	return {
		"id": wall_id,
		"start": [start_point.x, start_point.y, start_point.z],
		"end": [end_point.x, end_point.y, end_point.z],
		"height": wall_height,
		"thickness": wall_thickness
	}


func from_dict(data: Dictionary) -> void:
	if data.has("id"):
		wall_id = str(data["id"])
	if data.has("start") and data["start"] is Array and data["start"].size() == 3:
		start_point = Vector3(data["start"][0], data["start"][1], data["start"][2])
	if data.has("end") and data["end"] is Array and data["end"].size() == 3:
		end_point = Vector3(data["end"][0], data["end"][1], data["end"][2])
	if data.has("height"):
		wall_height = float(data["height"])
	if data.has("thickness"):
		wall_thickness = float(data["thickness"])
	update_geometry()
