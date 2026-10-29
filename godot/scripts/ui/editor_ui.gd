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

const FORMAT_ITEMS = [
	{"id": "original", "label": "Original"},
	{"id": "1:1", "label": "Cuadrado (1:1)"},
	{"id": "4:3", "label": "Horizontal (4:3)"},
	{"id": "16:9", "label": "Panorámico (16:9)"},
	{"id": "3:4", "label": "Vertical (3:4)"},
	{"id": "9:16", "label": "Retrato (9:16)"},
]

const FRAME_ITEMS = [
	{"id": "sin_marco", "label": "Sin marco (Lienzo)"},
	{"id": "madera", "label": "Marco Madera"},
	{"id": "negro", "label": "Marco Negro"},
	{"id": "blanco", "label": "Marco Blanco"},
	{"id": "dorado", "label": "Marco Dorado"},
]

var _props: PanelContainer
var _slider: HSlider
var _format_opt: OptionButton
var _frame_opt: OptionButton
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
	hb.add_child(_btn("Subir imagen", func(): manager.open_import()))
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
	_props.offset_left = -280
	_props.offset_right = -8
	_props.offset_top = 56
	_props.offset_bottom = 320
	_props.visible = false

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	_props.add_child(pv)

	var pt := Label.new()
	pt.text = "Propiedades del cuadro"
	pt.add_theme_font_size_override("font_size", 16)
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

	var fl := Label.new()
	fl.text = "Formato de cuadro"
	pv.add_child(fl)

	_format_opt = OptionButton.new()
	for item in FORMAT_ITEMS:
		_format_opt.add_item(item["label"])
	_format_opt.item_selected.connect(_on_format_changed)
	pv.add_child(_format_opt)

	var frl := Label.new()
	frl.text = "Estilo de marco"
	pv.add_child(frl)

	_frame_opt = OptionButton.new()
	for item in FRAME_ITEMS:
		_frame_opt.add_item(item["label"])
	_frame_opt.item_selected.connect(_on_frame_changed)
	pv.add_child(_frame_opt)

	pv.add_child(Control.new())
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

		for i in range(FORMAT_ITEMS.size()):
			if FORMAT_ITEMS[i]["id"] == art.current_format:
				_format_opt.selected = i
				break

		for i in range(FRAME_ITEMS.size()):
			if FRAME_ITEMS[i]["id"] == art.current_frame_style:
				_frame_opt.selected = i
				break

		_updating = false


## El usuario movió el slider: se aplica el nuevo ancho.
func _on_width_changed(v: float) -> void:
	if not _updating:
		manager.set_selected_width(v)


## El usuario cambió el formato de proporción del cuadro.
func _on_format_changed(index: int) -> void:
	if not _updating and index >= 0 and index < FORMAT_ITEMS.size():
		manager.set_selected_format(FORMAT_ITEMS[index]["id"])


## El usuario cambió el estilo del marco.
func _on_frame_changed(index: int) -> void:
	if not _updating and index >= 0 and index < FRAME_ITEMS.size():
		manager.set_selected_frame_style(FRAME_ITEMS[index]["id"])


## El usuario eligió algo de la biblioteca.
func _on_resource_chosen(r: Dictionary) -> void:
	var kind := str(r.get("type", "")).to_lower()
	if kind in ["image", "imagen", "obra"]:
		var path := str(r.get("file_url", r.get("file_path", "")))
		var url := Api.file_url(path)
		var img: Image = await Api.download_image(url)
		if img:
			manager.start_placing(img, url)
	else:
		model_requested.emit(r)


## Pasa al recorrido en primera persona (Modo visualizar).
func _go_viewer() -> void:
	if get_node_or_null("/root/GameState"):
		get_node("/root/GameState").set_mode(GameState.Mode.VISUALIZE)
	elif get_node_or_null("/root/AppManager"):
		get_node("/root/AppManager").cambiar_modo(AppManager.Modo.VISUALIZAR)
	get_tree().change_scene_to_file(viewer_scene)


## Vuelve a la pantalla inicial.
func _go_menu() -> void:
	get_tree().change_scene_to_file(main_menu_scene)