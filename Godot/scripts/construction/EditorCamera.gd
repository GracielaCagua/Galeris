class_name EditorCamera
extends Camera3D

## Cámara de vista isométrica / órbita / paneo para facilitar la construcción en Modo Crear.
## Se activa únicamente en Modo Crear para no interferir con la cámara en primera persona de Modo Visualizar.

@export var move_speed: float = 15.0
@export var rotate_speed: float = 0.005
@export var zoom_speed: float = 2.0
@export var min_zoom_dist: float = 2.0
@export var max_zoom_dist: float = 60.0

var pivot_point: Vector3 = Vector3(0.0, 0.0, 0.0)
var distance: float = 20.0
var pitch: float = -0.7 # Radianes (~ -40 grados)
var yaw: float = 0.0

var is_orbiting: bool = false
var is_panning: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_update_camera_transform()
	_update_active_state()
	
	if AppManager != null:
		AppManager.modo_cambiado.connect(_on_modo_cambiado)


func _on_modo_cambiado(_nuevo_modo) -> void:
	_update_active_state()


func _update_active_state() -> void:
	var can_edit: bool = AppManager.puede_editar()
	current = can_edit
	set_process_input(can_edit)
	set_process(can_edit)


func _unhandled_input(event: InputEvent) -> void:
	if not AppManager.puede_editar():
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - zoom_speed, min_zoom_dist, max_zoom_dist)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + zoom_speed, min_zoom_dist, max_zoom_dist)
			_update_camera_transform()
			
	elif event is InputEventMouseMotion:
		var delta_mouse: Vector2 = event.position - last_mouse_pos
		last_mouse_pos = event.position
		
		if is_orbiting:
			yaw -= delta_mouse.x * rotate_speed
			pitch = clampf(pitch - delta_mouse.y * rotate_speed, -1.5, -0.1)
			_update_camera_transform()
			
		elif is_panning:
			var right_vec := global_transform.basis.x
			var up_vec := global_transform.basis.y
			var pan_speed := distance * 0.002
			pivot_point -= right_vec * (delta_mouse.x * pan_speed)
			pivot_point += up_vec * (delta_mouse.y * pan_speed)
			_update_camera_transform()


func _process(delta: float) -> void:
	if not AppManager.puede_editar():
		return
		
	# Teclas WASD o flechas para mover el punto de pivote si se desea
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_UP):
		input_dir -= global_transform.basis.z
	if Input.is_key_pressed(KEY_DOWN):
		input_dir += global_transform.basis.z
	if Input.is_key_pressed(KEY_LEFT):
		input_dir -= global_transform.basis.x
	if Input.is_key_pressed(KEY_RIGHT):
		input_dir += global_transform.basis.x
		
	if input_dir.length_squared() > 0.0:
		input_dir.y = 0.0
		input_dir = input_dir.normalized()
		pivot_point += input_dir * (move_speed * delta)
		_update_camera_transform()


func _update_camera_transform() -> void:
	var rot_basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var cam_offset := rot_basis * Vector3(0.0, 0.0, distance)
	global_position = pivot_point + cam_offset
	look_at(pivot_point, Vector3.UP)
