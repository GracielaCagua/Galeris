## Indicador permanente del modo actual (abajo al centro de la pantalla).
##
## Uso: [code]add_child(ModeBanner.new())[/code] en el editor y en el visor.
## Se actualiza solo cuando [signal GameState.mode_changed] se emite.
class_name ModeBanner
extends CanvasLayer

var _label: Label
var _panel: PanelContainer


func _ready() -> void:
	layer = 50  # por encima del resto de la interfaz

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # no bloquea clics al 3D
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_top = -56
	_panel.offset_bottom = -12
	_panel.offset_left = -110
	_panel.offset_right = 110

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_panel.add_child(_label)

	GameState.mode_changed.connect(_refresh)
	_refresh(GameState.mode)


## Cambia texto y color según el modo recibido.
func _refresh(mode: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8)

	match mode:
		GameState.Mode.CREATE:
			_label.text = "✏ MODO CREAR"
			sb.bg_color = Color("#c4703a")
		GameState.Mode.VISUALIZE:
			_label.text = "👁 MODO VISUALIZAR"
			sb.bg_color = Color("#2e7d6b")
		_:
			_label.text = "SIN MODO"
			sb.bg_color = Color("#444444")

	_panel.add_theme_stylebox_override("panel", sb)