## Panel de la biblioteca de recursos: categorías, búsqueda y miniaturas.
##
## Obtiene los recursos desde el backend mediante [Api] y emite
## [signal resource_chosen] cuando el usuario elige uno.
extends PanelContainer

## Se emite al pulsar un recurso. [param resource] es el diccionario tal como
## lo devuelve el backend (name, category, type, file_path, thumbnail_path...).
signal resource_chosen(resource: Dictionary)

## Lista completa de recursos descargada del backend (sin filtrar).
var _all: Array = []
var _search: LineEdit
var _cat: OptionButton
var _grid: GridContainer


func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)

	var v := VBoxContainer.new()
	add_child(v)

	var title := Label.new()
	title.text = "Biblioteca de recursos"
	title.add_theme_font_size_override("font_size", 18)
	v.add_child(title)

	_cat = OptionButton.new()
	_cat.add_item("Todas")
	_cat.item_selected.connect(func(_i): _render())
	v.add_child(_cat)

	_search = LineEdit.new()
	_search.placeholder_text = "Buscar..."
	_search.text_changed.connect(func(_t): _render())
	v.add_child(_search)

	var refresh_btn := Button.new()
	refresh_btn.text = "Actualizar"
	refresh_btn.pressed.connect(refresh)
	v.add_child(refresh_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	refresh()


## Vuelve a pedir los recursos al backend y reconstruye categorías y cuadrícula.
func refresh() -> void:
	_all = await Api.list_resources()

	# Se arma la lista de categorías sin repetir (un Dictionary funciona como conjunto).
	var cats := {}
	for r in _all:
		cats[str(r.get("category", ""))] = true

	_cat.clear()
	_cat.add_item("Todas")
	for c in cats.keys():
		if c != "":
			_cat.add_item(c)

	_render()


## Dibuja las tarjetas aplicando el filtro de categoría y el texto de búsqueda.
func _render() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var cat_text := _cat.get_item_text(_cat.selected) if _cat.selected >= 0 else "Todas"
	var q := _search.text.strip_edges().to_lower()

	for r in _all:
		if cat_text != "Todas" and str(r.get("category", "")) != cat_text:
			continue
		if q != "" and not str(r.get("name", "")).to_lower().contains(q):
			continue
		_add_card(r)


## Crea la tarjeta de un recurso y descarga su miniatura en segundo plano.
func _add_card(r: Dictionary) -> void:
	var b := Button.new()
	b.text = str(r.get("name", "?"))
	b.custom_minimum_size = Vector2(130, 130)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.clip_text = true
	b.pressed.connect(func(): resource_chosen.emit(r))
	_grid.add_child(b)

	var thumb := str(r.get("thumbnail_path", ""))
	if thumb != "":
		var img: Image = await Api.download_image(Api.file_url(thumb))
		# El botón pudo borrarse mientras se descargaba (si se filtró de nuevo).
		if img != null and is_instance_valid(b):
			b.icon = ImageTexture.create_from_image(img)