extends Node3D

@onready var modo_label: Label = $UI/ModoLabel
@onready var wall_container: Node3D = $World/Objetos

var _selected_wall: GalleryWall
var _dragging := false
var _toolbar: HBoxContainer
var _width_input: SpinBox
var _height_input: SpinBox
var _camera: Camera3D
var _wall_script = preload("res://scripts/core/Wall.gd")
var _wall_counter := 1

func _ready() -> void:
	AppMode.mode_changed.connect(_on_mode_changed)
	_camera = $World/Camera3D
	_build_wall_toolbar()
	$UI/BotonVisualizar.pressed.connect(func(): AppMode.change_mode(AppMode.Mode.VISUALIZE))
	$UI/BotonCrear.pressed.connect(func(): AppMode.change_mode(AppMode.Mode.CREATE))
	ProjectManager.load_scene(wall_container)
	_actualizar_interfaz()

	print("Modo inicial: ", AppMode.mode_name())
	print("¿Puede editar?: ", AppMode.can_edit())

func _unhandled_input(event: InputEvent) -> void:
	if not AppMode.can_edit():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_select_wall(event.position)
			_dragging = _selected_wall != null
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging and _selected_wall != null:
		var point: Variant = _floor_point(event.position)
		if point != null:
			_selected_wall.global_position.x = point.x
			_selected_wall.global_position.z = point.z


func _on_mode_changed(_new_mode) -> void:
	_actualizar_interfaz()

	print("Modo actual: ", AppMode.mode_name())


func _actualizar_interfaz() -> void:
	modo_label.text = AppMode.mode_name()
	_toolbar.visible = AppMode.can_edit()
	$UI/BotonCrear.disabled = AppMode.can_edit()
	$UI/BotonVisualizar.disabled = not AppMode.can_edit()

func _build_wall_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.name = "HerramientasPared"
	_toolbar.position = Vector2(20, 105)
	$UI.add_child(_toolbar)
	_add_button("Agregar pared", _add_wall)
	_add_button("Girar 90°", func(): _rotate_selected(PI * 0.5))
	_add_button("Girar 180°", func(): _rotate_selected(PI))
	_add_button("Orientación inicial", _reset_rotation)
	_add_button("Guardar", func(): _show_result(ProjectManager.save_scene(wall_container)))
	_add_button("Cargar", func():
		ProjectManager.load_scene(wall_container)
		_select(null)
	)
	_width_input = _add_dimension("Ancho", 4.0)
	_height_input = _add_dimension("Alto", 3.0)

func _add_button(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	_toolbar.add_child(button)

func _add_dimension(label: String, initial: float) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = 0.1
	box.max_value = 30.0
	box.step = 0.1
	box.value = initial
	box.prefix = label + ": "
	box.value_changed.connect(_apply_dimensions)
	_toolbar.add_child(box)
	return box

func _add_wall() -> void:
	if not AppMode.guard("agregar pared"):
		return
	var wall: GalleryWall = _wall_script.new()
	wall.name = "Pared_%03d" % _wall_counter
	wall.position = Vector3(float(_wall_counter - 1) * 4.5, 0, 0)
	_wall_counter += 1
	wall.configure("pared_%s" % str(Time.get_ticks_usec()))
	wall_container.add_child(wall)
	_select(wall)

func _select_wall(screen_position: Vector2) -> void:
	var from := _camera.project_ray_origin(screen_position)
	var to := from + _camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_select(hit.get("collider") as GalleryWall if hit else null)

func _floor_point(screen_position: Vector2) -> Variant:
	var from := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return null
	var distance := -from.y / direction.y
	if distance < 0:
		return null
	return from + direction * distance

func _select(wall: GalleryWall) -> void:
	_selected_wall = wall
	if wall != null:
		_width_input.value = wall.width
		_height_input.value = wall.height

func _rotate_selected(radians: float) -> void:
	if AppMode.guard("girar pared") and _selected_wall != null:
		_selected_wall.rotation.y += radians

func _reset_rotation() -> void:
	if AppMode.guard("restablecer orientación") and _selected_wall != null:
		_selected_wall.rotation.y = 0.0

func _apply_dimensions(_value: float) -> void:
	if AppMode.can_edit() and _selected_wall != null:
		_selected_wall.set_dimensions(_width_input.value, _height_input.value)

func _show_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		push_error("Error de proyecto: " + str(result.get("mensaje", "desconocido")))
