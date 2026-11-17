class_name ConstructionSystem
extends Node3D

## Sistema principal de construcción para el Modo Crear (Persona 3).
## Gestiona la creación de paredes (inicio/fin), selección, movimiento, eliminación,
## medidas configurables, snapping y la integración con el formato de guardado.

enum ConstructionTool {
	NONE,
	BUILD_WALL,
	SELECT_WALL
}

signal tool_changed(new_tool: ConstructionTool)
signal wall_created(wall: Wall)
signal wall_selected(wall: Wall)
signal wall_deselected()
signal wall_deleted(wall_id: String)
signal wall_property_changed(height: float, thickness: float)

@export var wall_scene: PackedScene
@export var floor_scene: PackedScene

# Parámetros básicos de pared
@export var default_wall_height: float = 3.0
@export var default_wall_thickness: float = 0.2

var current_wall_height: float = 3.0
var current_wall_thickness: float = 0.2

var current_tool: ConstructionTool = ConstructionTool.BUILD_WALL:
	set = set_tool

# Referencias
@onready var walls_container: Node3D = $WallsContainer
@onready var grid_snapping: GridSnapping = $GridSnapping
@onready var editor_camera: EditorCamera = $EditorCamera

# Estado de construcción de paredes
var is_placing_wall: bool = false
var wall_start_point: Vector3 = Vector3.ZERO
var preview_wall: Wall = null

# Estado de selección
var selected_wall: Wall = null
var is_moving_selected_wall: bool = false
var move_start_plane_pos: Vector3 = Vector3.ZERO
var move_wall_initial_start: Vector3 = Vector3.ZERO
var move_wall_initial_end: Vector3 = Vector3.ZERO

# Colección de paredes en memoria
var walls: Array[Wall] = []


func _ready() -> void:
	current_wall_height = default_wall_height
	current_wall_thickness = default_wall_thickness
	
	if wall_scene == null:
		wall_scene = load("res://scenes/construction/Wall.tscn")
	if floor_scene == null:
		floor_scene = load("res://scenes/construction/Floor.tscn")
		
	_ensure_base_floor()
	_create_preview_wall()
	
	if AppManager != null:
		AppManager.modo_cambiado.connect(_on_modo_cambiado)
		
	_update_for_current_mode()


func _ensure_base_floor() -> void:
	# Asegurar que exista un piso base en la escena
	var existing_floor = get_tree().get_first_node_in_group("floor")
	if existing_floor == null:
		var floor_instance: Floor = floor_scene.instantiate()
		floor_instance.name = "BaseFloor"
		add_child(floor_instance)


func _create_preview_wall() -> void:
	if preview_wall != null:
		preview_wall.queue_free()
		
	preview_wall = wall_scene.instantiate()
	preview_wall.name = "PreviewWall"
	preview_wall.is_preview = true
	preview_wall.visible = false
	add_child(preview_wall)


func _on_modo_cambiado(_nuevo_modo) -> void:
	_update_for_current_mode()


func _update_for_current_mode() -> void:
	var can_edit: bool = AppManager.puede_editar()
	
	# Si pasamos a Modo Visualizar, limpiar estados de edición
	if not can_edit:
		cancel_current_action()
		deselect_wall()
		if preview_wall != null:
			preview_wall.visible = false
			
	set_process_unhandled_input(can_edit)


func set_tool(new_tool: ConstructionTool) -> void:
	if current_tool == new_tool:
		return
		
	cancel_current_action()
	current_tool = new_tool
	tool_changed.emit(current_tool)


func set_wall_dimensions(height: float, thickness: float) -> void:
	current_wall_height = clampf(height, 0.5, 10.0)
	current_wall_thickness = clampf(thickness, 0.05, 2.0)
	
	# Si hay una pared seleccionada, actualizar sus dimensiones inmediatamente
	if selected_wall != null:
		selected_wall.setup(
			selected_wall.start_point,
			selected_wall.end_point,
			current_wall_height,
			current_wall_thickness
		)
	
	wall_property_changed.emit(current_wall_height, current_wall_thickness)


func _unhandled_input(event: InputEvent) -> void:
	if not AppManager.puede_editar():
		return
		
	# Tecla ESC para cancelar acción actual o deseleccionar
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if is_placing_wall or is_moving_selected_wall:
			cancel_current_action()
		elif selected_wall != null:
			deselect_wall()
		return
		
	# Teclas SUPR / Retroceso para eliminar pared seleccionada
	if (event is InputEventKey and event.pressed and not event.echo) and (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE):
		if selected_wall != null:
			delete_selected_wall()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_current_action()
			
	elif event is InputEventMouseMotion:
		_handle_mouse_motion()


func _get_ground_intersection() -> Variant:
	var viewport := get_viewport()
	if viewport == null:
		return null
	var mouse_pos := viewport.get_mouse_position()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return null
		
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)
	
	# Intersección con el plano Y = 0 (nivel del piso)
	var ground_plane := Plane(Vector3.UP, 0.0)
	var hit_pos = ground_plane.intersects_ray(ray_origin, ray_normal)
	return hit_pos


func _handle_left_click() -> void:
	var hit = _get_ground_intersection()
	if hit == null:
		return
	var hit_pos: Vector3 = hit
	
	match current_tool:
		ConstructionTool.BUILD_WALL:
			_handle_wall_build_click(hit_pos)
		ConstructionTool.SELECT_WALL:
			_handle_wall_select_click(hit_pos)


func _handle_wall_build_click(hit_pos: Vector3) -> void:
	if not is_placing_wall:
		# Primer clic: Punto inicial
		wall_start_point = grid_snapping.snap_position(hit_pos)
		is_placing_wall = true
		
		if preview_wall != null:
			preview_wall.setup(
				wall_start_point,
				wall_start_point + Vector3(0.01, 0, 0),
				current_wall_height,
				current_wall_thickness
			)
			preview_wall.visible = true
	else:
		# Segundo clic: Punto final
		var end_pos := grid_snapping.snap_wall_endpoint(wall_start_point, hit_pos)
		var length := wall_start_point.distance_to(end_pos)
		
		if length >= 0.3:
			create_wall(wall_start_point, end_pos, current_wall_height, current_wall_thickness)
			# Permitir encadenar la siguiente pared desde el punto final
			wall_start_point = end_pos
			if preview_wall != null:
				preview_wall.setup(
					wall_start_point,
					wall_start_point + Vector3(0.01, 0, 0),
					current_wall_height,
					current_wall_thickness
				)
		else:
			print("Pared demasiado corta (mínimo 0.3m).")


func _handle_wall_select_click(_hit_pos: Vector3) -> void:
	# El clic sobre la pared se maneja directamente vía señal wall_clicked desde Wall.gd
	pass


func _handle_mouse_motion() -> void:
	var hit = _get_ground_intersection()
	if hit == null:
		return
	var hit_pos: Vector3 = hit
	
	if current_tool == ConstructionTool.BUILD_WALL and is_placing_wall:
		var end_pos := grid_snapping.snap_wall_endpoint(wall_start_point, hit_pos)
		if preview_wall != null:
			preview_wall.setup(
				wall_start_point,
				end_pos,
				current_wall_height,
				current_wall_thickness
			)
			preview_wall.visible = true
			
	elif current_tool == ConstructionTool.SELECT_WALL and is_moving_selected_wall and selected_wall != null:
		var snapped_hit := grid_snapping.snap_position(hit_pos)
		var offset := snapped_hit - move_start_plane_pos
		selected_wall.start_point = move_wall_initial_start + offset
		selected_wall.end_point = move_wall_initial_end + offset
		selected_wall.update_geometry()


func create_wall(start: Vector3, end: Vector3, height: float, thickness: float, custom_id: String = "") -> Wall:
	var new_wall: Wall = wall_scene.instantiate()
	if not custom_id.is_empty():
		new_wall.wall_id = custom_id
		
	walls_container.add_child(new_wall)
	new_wall.setup(start, end, height, thickness)
	new_wall.wall_clicked.connect(_on_wall_clicked)
	walls.append(new_wall)
	
	wall_created.emit(new_wall)
	print("Pared creada con éxito: ", new_wall.wall_id, " | Longitud: %.2fm" % start.distance_to(end))
	return new_wall


func _on_wall_clicked(wall: Wall) -> void:
	if not AppManager.puede_editar():
		return
		
	if current_tool == ConstructionTool.SELECT_WALL:
		select_wall(wall)


func select_wall(wall: Wall) -> void:
	if selected_wall == wall:
		return
		
	deselect_wall()
	selected_wall = wall
	selected_wall.set_selected(true)
	
	# Sincronizar dimensiones con los valores de la pared seleccionada
	current_wall_height = selected_wall.wall_height
	current_wall_thickness = selected_wall.wall_thickness
	wall_property_changed.emit(current_wall_height, current_wall_thickness)
	
	wall_selected.emit(selected_wall)
	print("Pared seleccionada: ", selected_wall.wall_id)


func deselect_wall() -> void:
	if selected_wall != null:
		selected_wall.set_selected(false)
		selected_wall = null
		wall_deselected.emit()


func start_moving_selected_wall() -> void:
	if selected_wall == null:
		return
	var hit = _get_ground_intersection()
	if hit != null:
		is_moving_selected_wall = true
		move_start_plane_pos = grid_snapping.snap_position(hit)
		move_wall_initial_start = selected_wall.start_point
		move_wall_initial_end = selected_wall.end_point


func stop_moving_selected_wall() -> void:
	is_moving_selected_wall = false


func delete_selected_wall() -> void:
	if selected_wall == null:
		return
		
	var deleted_id := selected_wall.wall_id
	delete_wall(selected_wall)
	selected_wall = null
	wall_deleted.emit(deleted_id)


func delete_wall(wall: Wall) -> void:
	if wall == null:
		return
		
	if wall == selected_wall:
		selected_wall = null
		wall_deselected.emit()
		
	walls.erase(wall)
	wall.queue_free()
	print("Pared eliminada: ", wall.wall_id)


func cancel_current_action() -> void:
	is_placing_wall = false
	is_moving_selected_wall = false
	if preview_wall != null:
		preview_wall.visible = false


func clear_all_walls() -> void:
	cancel_current_action()
	deselect_wall()
	for wall in walls:
		if is_instance_valid(wall):
			wall.queue_free()
	walls.clear()
	print("Todas las paredes han sido eliminadas.")


# --- INTEGRACIÓN CON PROJECTMANAGER (PERSONA 1) ---

## Exporta los datos de todas las paredes en el formato JSON de guardado
func get_walls_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wall in walls:
		if is_instance_valid(wall):
			result.append(wall.to_dict())
	return result


## Carga las paredes desde un array de datos deserializado de JSON
func load_walls_from_data(walls_data: Array) -> void:
	clear_all_walls()
	
	for wall_dict in walls_data:
		if wall_dict is Dictionary:
			var start := Vector3.ZERO
			var end := Vector3.FORWARD
			var height := default_wall_height
			var thickness := default_wall_thickness
			var wall_id := ""
			
			if wall_dict.has("id"):
				wall_id = str(wall_dict["id"])
			if wall_dict.has("start") and wall_dict["start"] is Array and wall_dict["start"].size() == 3:
				start = Vector3(wall_dict["start"][0], wall_dict["start"][1], wall_dict["start"][2])
			if wall_dict.has("end") and wall_dict["end"] is Array and wall_dict["end"].size() == 3:
				end = Vector3(wall_dict["end"][0], wall_dict["end"][1], wall_dict["end"][2])
			if wall_dict.has("height"):
				height = float(wall_dict["height"])
			if wall_dict.has("thickness"):
				thickness = float(wall_dict["thickness"])
				
			create_wall(start, end, height, thickness, wall_id)
			
	print("Se cargaron %d paredes desde el proyecto." % walls.size())
