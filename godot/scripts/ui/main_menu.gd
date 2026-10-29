## Pantalla inicial: selector entre Modo visualizar y Modo crear.
##
## Se adjunta al nodo raíz (tipo [Control]) de scenes/ui/main_menu.tscn.
## Toda la interfaz se construye por código, así no hay que armar nodos a mano.
extends Control

## Escena del editor (Modo crear). La entrega la Persona 1 / 3.
const EDITOR_SCENE := "res://scenes/editor/editor.tscn"
## Escena del recorrido en primera persona (Modo visualizar). La entrega la Persona 2.
const VIEWER_SCENE := "res://scenes/viewer/viewer.tscn"

## Muestra mensajes al usuario (por ejemplo, si una escena aún no existe).
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.set_mode(GameState.Mode.NONE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # el visor oculta el mouse; aquí lo recuperamos
	_build_ui()


## Construye fondo, título y las dos tarjetas de modo.
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#12141a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	var title := Label.new()
	title.text = "Galería Facultad de Artes"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Elige cómo quieres entrar"
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(1, 1, 1, 0.7)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	# Cada color distinto ayuda a diferenciar los modos a simple vista.
	var view_btn := _make_card(
		"MODO VISUALIZAR",
		"Recorre las salas en primera persona. Solo lectura: nada se puede editar.",
		Color("#2e7d6b"))
	view_btn.pressed.connect(_start.bind(GameState.Mode.VISUALIZE, VIEWER_SCENE))
	row.add_child(view_btn)

	var create_btn := _make_card(
		"MODO CREAR",
		"Construye salas, coloca modelos 3D y cuelga obras de arte.",
		Color("#c4703a"))
	create_btn.pressed.connect(_start.bind(GameState.Mode.CREATE, EDITOR_SCENE))
	row.add_child(create_btn)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color("#ffd27a")
	box.add_child(_status)


## Crea un botón grande con título y descripción, con estilo propio por estado.
## [param color] es el color base; se oscurece/aclara según el estado del botón.
func _make_card(title: String, desc: String, color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(340, 210)
	b.text = "%s\n\n%s" % [title, desc]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 20)

	var colors := {
		"normal": color.darkened(0.4),
		"hover": color,
		"pressed": color.lightened(0.15),
	}
	for state in colors:
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[state]
		sb.set_corner_radius_all(18)
		sb.set_content_margin_all(20)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Fija el modo elegido y cambia de escena.
## Si la escena aún no existe (porque otro compañero no la ha subido), avisa en pantalla.
func _start(mode: int, scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		_status.text = "Esa escena aún no está disponible: " + scene_path
		return
	GameState.set_mode(mode)
	get_tree().change_scene_to_file(scene_path)