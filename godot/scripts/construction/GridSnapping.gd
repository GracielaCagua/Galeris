class_name GridSnapping
extends Node3D

## Sistema de cuadrícula y snapping para el Modo Crear.
## Proporciona ajuste espacial por coordenadas y ángulos, así como una cuadrícula visual.

@export var snap_enabled: bool = true
@export var grid_step: float = 1.0: # metros
	set = set_grid_step
@export var grid_size: float = 40.0: # tamaño total de la cuadrícula
	set = set_grid_size
@export var angle_snap_enabled: bool = true
@export var angle_step_deg: float = 45.0 # grados

var grid_mesh_instance: MeshInstance3D


func _ready() -> void:
	_create_visual_grid()
	_update_visibility()
	
	if AppManager != null:
		AppManager.modo_cambiado.connect(_on_modo_cambiado)


func set_grid_step(val: float) -> void:
	grid_step = max(0.1, val)
	_create_visual_grid()


func set_grid_size(val: float) -> void:
	grid_size = max(5.0, val)
	_create_visual_grid()


func snap_position(pos: Vector3) -> Vector3:
	if not snap_enabled or grid_step <= 0.0:
		return pos
	
	return Vector3(
		snappedf(pos.x, grid_step),
		pos.y, # mantenemos la altura
		snappedf(pos.z, grid_step)
	)


func snap_wall_endpoint(start: Vector3, current: Vector3, force_angle_snap: bool = false) -> Vector3:
	var snapped_pos := snap_position(current)
	
	if angle_snap_enabled or force_angle_snap:
		var diff := snapped_pos - start
		var horizontal_dist := Vector2(diff.x, diff.z).length()
		
		if horizontal_dist > 0.1:
			var angle_rad := atan2(diff.z, diff.x)
			var step_rad := deg_to_rad(angle_step_deg)
			var snapped_angle := round(angle_rad / step_rad) * step_rad
			
			snapped_pos.x = start.x + cos(snapped_angle) * horizontal_dist
			snapped_pos.z = start.z + sin(snapped_angle) * horizontal_dist
			
			if snap_enabled:
				snapped_pos = snap_position(snapped_pos)
				
	return snapped_pos


func _create_visual_grid() -> void:
	if grid_mesh_instance != null:
		grid_mesh_instance.queue_free()
	
	grid_mesh_instance = MeshInstance3D.new()
	grid_mesh_instance.name = "VisualGrid"
	add_child(grid_mesh_instance)
	
	var im_mesh := ImmediateMesh.new()
	var half_size := grid_size * 0.5
	var count := int(grid_size / grid_step)
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.45, 0.6, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	im_mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	
	var start_coord := -half_size
	for i in range(count + 1):
		var coord := start_coord + (i * grid_step)
		
		# Línea a lo largo de Z
		im_mesh.surface_add_vertex(Vector3(coord, 0.02, -half_size))
		im_mesh.surface_add_vertex(Vector3(coord, 0.02, half_size))
		
		# Línea a lo largo de X
		im_mesh.surface_add_vertex(Vector3(-half_size, 0.02, coord))
		im_mesh.surface_add_vertex(Vector3(half_size, 0.02, coord))
		
	im_mesh.surface_end()
	grid_mesh_instance.mesh = im_mesh


func _on_modo_cambiado(_nuevo_modo) -> void:
	_update_visibility()


func _update_visibility() -> void:
	# La cuadrícula solo se muestra en Modo Crear
	visible = AppManager.puede_editar()
