## Gestor de obras: importar, colocar, mover, escalar y eliminar cuadros.
##
## Se coloca como nodo [Node3D] en la escena del editor. Las obras son sus hijas.
## Todas las acciones están bloqueadas fuera del Modo crear mediante
## [method GameState.can_edit].
class_name ArtworkManager
extends Node3D

## Se emite cuando cambia la obra seleccionada ([code]null[/code] = ninguna).
signal selection_changed(art: Artwork)

## Cámara del editor, necesaria para lanzar rayos desde el mouse.
@export var camera: Camera3D

## Capa de colisión de las paredes (Persona 3).
const WALL_MASK := 1
## Capa de colisión de las obras.
const ART_MASK := 2

## Obra seleccionada actualmente.
var selected: Artwork = null

# Imagen que está "en la mano" esperando un clic sobre una pared.
var _pending_img: Image = null
var _pending_src := ""
var _dragging := false
var _dialog: FileDialog


func _ready() -> void:
	_dialog = FileDialog.new()
	_dialog.title = "Elegir obra de arte"
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.jpg, *.jpeg, *.png, *.webp ; Imágenes"])
	_dialog.size = Vector2i(800, 500)
	_dialog.file_selected.connect(_on_file_selected)
	add_child(_dialog)

	GameState.mode_changed.connect(_on_mode_changed)


## Al salir del Modo crear se cancela todo lo que esté en curso.
func _on_mode_changed(_mode: int) -> void:
	if not GameState.can_edit():
		cancel_placing()
		_select(null)


# ===================== API pública (la usa la interfaz) =====================

## Abre el explorador de archivos para elegir una imagen (JPG, PNG o WEBP).
func open_import() -> void:
	if GameState.can_edit():
		_dialog.popup_centered()


## Deja una imagen lista para colgarla con el siguiente clic sobre una pared.
func start_placing(img: Image, source: String) -> void:
	if not GameState.can_edit():
		return
	_pending_img = img
	_pending_src = source
	_select(null)


## Cancela la colocación pendiente.
func cancel_placing() -> void:
	_pending_img = null
	_pending_src = ""


## Cambia el ancho de la obra seleccionada (en metros).
func set_selected_width(w: float) -> void:
	if GameState.can_edit() and selected:
		selected.set_width(w)


## Elimina la obra seleccionada.
func delete_selected() -> void:
	if GameState.can_edit() and selected:
		var art := selected
		_select(null)
		art.queue_free()


## Devuelve todas las obras como [Array] de diccionarios, para guardar el proyecto.
func serialize() -> Array:
	var out := []
	for c in get_children():
		if c is Artwork:
			out.append(c.to_dict())
	return out


## Reconstruye las obras desde datos guardados (lo contrario de [method serialize]).
## Descarga imágenes remotas si el origen es una URL; las omite si no se pueden cargar.
func load_from(data: Array) -> void:
	for c in get_children():
		if c is Artwork:
			c.queue_free()

	for d in data:
		var src := str(d.get("source", ""))
		var img: Image = null
		if src.begins_with("http"):
			img = await Api.download_image(src)
		else:
			img = Image.load_from_file(src)
		if img == null or img.is_empty():
			continue

		var art := Artwork.new()
		art.set_image(img, src)
		art.set_width(float(d.get("width", 1.0)))
		add_child(art)

		var p: Array = d.get("position", [0, 0, 0])
		var r: Array = d.get("rotation", [0, 0, 0])
		art.position = Vector3(p[0], p[1], p[2])
		art.rotation = Vector3(r[0], r[1], r[2])


# ============================== Entrada ==============================

## Se llama al elegir un archivo en el diálogo de importación.
func _on_file_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		push_warning("No se pudo cargar la imagen: " + path)
		return
	start_placing(img, path)


## Maneja mouse y teclado. Usa _unhandled_input para no interferir con los botones de la UI.
func _unhandled_input(event: InputEvent) -> void:
	# Candado principal: en Modo visualizar no se procesa nada.
	if not GameState.can_edit() or camera == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_press()
			else:
				_dragging = false
		elif event.pressed and event.shift_pressed and selected:
			# Shift + rueda = escalar la obra seleccionada.
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				selected.set_width(selected.width + 0.1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				selected.set_width(selected.width - 0.1)

	elif event is InputEventMouseMotion and _dragging and selected:
		# Arrastrando: la obra sigue al mouse sobre la pared.
		var wall_hit := _raycast(WALL_MASK)
		if not wall_hit.is_empty():
			_place(selected, wall_hit)

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE:
			delete_selected()
		elif event.keycode == KEY_ESCAPE:
			cancel_placing()


## Clic izquierdo: cuelga la obra pendiente o selecciona/empieza a arrastrar una existente.
func _on_left_press() -> void:
	if _pending_img != null:
		var wall_hit := _raycast(WALL_MASK)
		if wall_hit.is_empty():
			return
		var art := Artwork.new()
		art.set_image(_pending_img, _pending_src)
		add_child(art)
		_place(art, wall_hit)
		cancel_placing()
		_select(art)
		return

	var art_hit := _raycast(ART_MASK)
	if art_hit.is_empty():
		_select(null)
	else:
		_select(art_hit.collider as Artwork)
		_dragging = true


## Cambia la selección, quitando el resaltado de la anterior.
func _select(art: Artwork) -> void:
	if selected and is_instance_valid(selected):
		selected.set_highlight(false)
	selected = art
	if selected:
		selected.set_highlight(true)
	selection_changed.emit(selected)


## Lanza un rayo desde el mouse y devuelve el primer choque en las capas de [param mask].
## Devuelve un diccionario vacío si no golpea nada.
func _raycast(mask: int) -> Dictionary:
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var to := from + camera.project_ray_normal(mp) * 100.0
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)


## Coloca la obra pegada a la pared, mirando hacia afuera. Ignora piso y techo.
func _place(art: Artwork, hit: Dictionary) -> void:
	var n: Vector3 = hit.normal
	if absf(n.dot(Vector3.UP)) > 0.99:
		return
	art.global_position = hit.position + n * 0.02  # 2 cm separada para evitar parpadeo
	art.look_at(art.global_position - n, Vector3.UP)