## Interfaz del editor 3D (Modo crear).
##
## Contiene: barra superior, biblioteca de recursos (izquierda) y panel de
## propiedades de la obra seleccionada (derecha). Se usa como [CanvasLayer]
## dentro de la escena del editor.
extends CanvasLayer

## Se emite cuando el usuario elige un modelo 3D en la biblioteca.
## La Persona 4 se conecta a esta señal para colocar el modelo.
signal model_requested(resource: Dictionary)

## Gestor de obras de la escena (se asigna desde el Inspector).
@export var manager: ArtworkManager
## Escena del menú principal.
@export var main_menu_scene := "res://scenes/ui/main_menu.tscn"
## Escena del recorrido en primera persona.
@export var viewer_scene := "res://scenes/viewer/viewer.tscn"

var _props: PanelContainer
var _slider: HSlider
# Evita que mover el slider por código vuelva a disparar el cambio de ancho.
var _updating := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # deja pasar los clics al mundo 3D
	add_child(root)

	_build_top_bar(root)
	_build_library(root)
	_build_properties(root)

	add_child(ModeBanner.new())  # indicador del modo actual

	if manager:
		manager.selection_changed.connect(_on_selection)


## Barra superior con botones y ayuda de controles.
func _build_top_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	var hb := HBoxContainer.new()
	bar.add_child(hb)
	hb.add_child(_btn("Importar imagen", func(): manager.open_import()))
	hb.add_child(_btn("Recorrido", _go_viewer))
	hb.add_child(_btn("Menú principal", _go_menu))

	var hint := Label.new()
	hint.text = "  Clic: seleccionar/mover · Shift+rueda: escalar · Supr: eliminar · Esc: cancelar"
	hint.modulate = Color(1, 1, 1, 0.6)
	hb.add_child(hint)


## Biblioteca de recursos pegada al borde izquierdo.
func _build_library(root: Control) -> void:
	var lib := preload("res://scripts/ui/resource_library.gd").new()
	root.add_child(lib)
	lib.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	lib.offset_top = 48
	lib.offset_right = 300
	lib.resource_chosen.connect(_on_resource_chosen)


## Panel de propiedades (oculto hasta que se selecciona una obra).
func _build_properties(root: Control) -> void:
	_props = PanelContainer.new()
	root.add_child(_props)
	_props.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_props.offset_left = -260
	_props.offset_right = -8
	_props.offset_top = 56
	_props.offset_bottom = 200
	_props.visible = false

	var pv := VBoxContainer.new()
	_props.add_child(pv)

	var pt := Label.new()
	pt.text = "Propiedades de la obra"
	pv.add_child(pt)

	var wl := Label.new()
	wl.text = "Ancho (m)"
	pv.add_child(wl)

	_slider = HSlider.new()
	_slider.min_value = 0.2
	_slider.max_value = 6.0
	_slider.step = 0.05
	_slider.value_changed.connect(_on_width_changed)
	pv.add_child(_slider)

	pv.add_child(_btn("Eliminar obra", func(): manager.delete_selected()))


## Crea un botón con texto y acción. Evita repetir código.
func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


## Muestra u oculta el panel de propiedades según haya obra seleccionada.
func _on_selection(art: Artwork) -> void:
	_props.visible = art != null
	if art:
		_updating = true
		_slider.value = art.width
		_updating = false


## El usuario movió el slider: se aplica el nuevo ancho.
func _on_width_changed(v: float) -> void:
	if not _updating:
		manager.set_selected_width(v)


## El usuario eligió algo de la biblioteca.
## Imágenes: se descargan y quedan listas para colgar. Modelos 3D: se delegan.
func _on_resource_chosen(r: Dictionary) -> void:
	var kind := str(r.get("type", "")).to_lower()
	if kind in ["image", "imagen", "obra"]:
		var url := Api.file_url(str(r.get("file_path", "")))
		var img: Image = await Api.download_image(url)
		if img:
			manager.start_placing(img, url)
	else:
		model_requested.emit(r)


## Pasa al recorrido en primera persona (Modo visualizar).
func _go_viewer() -> void:
	GameState.set_mode(GameState.Mode.VISUALIZE)
	get_tree().change_scene_to_file(viewer_scene)


## Vuelve a la pantalla inicial.
func _go_menu() -> void:
	get_tree().change_scene_to_file(main_menu_scene)