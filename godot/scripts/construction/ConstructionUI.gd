class_name ConstructionUI
extends Control

## Interfaz gráfica de usuario para las herramientas de construcción del Modo Crear (Persona 3).
## Se oculta y deshabilita automáticamente cuando la aplicación está en Modo Visualizar.

@export var construction_system_path: NodePath
var construction_system: ConstructionSystem

# Nodos de la UI
@onready var panel_container: PanelContainer = $PanelContainer
@onready var btn_build_wall: Button = %BtnBuildWall
@onready var btn_select: Button = %BtnSelect
@onready var btn_delete: Button = %BtnDelete
@onready var btn_clear_all: Button = %BtnClearAll

@onready var spin_height: SpinBox = %SpinHeight
@onready var spin_thickness: SpinBox = %SpinThickness

@onready var check_snap: CheckBox = %CheckSnap
@onready var opt_snap_size: OptionButton = %OptSnapSize
@onready var check_angle_snap: CheckBox = %CheckAngleSnap

@onready var lbl_status: Label = %LblStatus
@onready var info_panel: PanelContainer = %InfoPanel


func _ready() -> void:
	if not construction_system_path.is_empty():
		construction_system = get_node_or_null(construction_system_path)
	elif get_parent() is ConstructionSystem:
		construction_system = get_parent()
	else:
		construction_system = get_tree().get_first_node_in_group("construction_system")
		
	_connect_signals()
	_populate_snap_options()
	_update_visibility()
	
	if AppManager != null:
		AppManager.modo_cambiado.connect(_on_modo_cambiado)


func _populate_snap_options() -> void:
	if opt_snap_size == null:
		return
	opt_snap_size.clear()
	opt_snap_size.add_item("0.25 m", 0)
	opt_snap_size.add_item("0.50 m", 1)
	opt_snap_size.add_item("1.00 m", 2)
	opt_snap_size.add_item("2.00 m", 3)
	opt_snap_size.select(2) # 1.00 m por defecto


func _connect_signals() -> void:
	if btn_build_wall != null:
		btn_build_wall.pressed.connect(_on_build_wall_pressed)
	if btn_select != null:
		btn_select.pressed.connect(_on_select_pressed)
	if btn_delete != null:
		btn_delete.pressed.connect(_on_delete_pressed)
	if btn_clear_all != null:
		btn_clear_all.pressed.connect(_on_clear_all_pressed)
		
	if spin_height != null:
		spin_height.value_changed.connect(_on_dimensions_changed)
	if spin_thickness != null:
		spin_thickness.value_changed.connect(_on_dimensions_changed)
		
	if check_snap != null:
		check_snap.toggled.connect(_on_snap_toggled)
	if opt_snap_size != null:
		opt_snap_size.item_selected.connect(_on_snap_size_selected)
	if check_angle_snap != null:
		check_angle_snap.toggled.connect(_on_angle_snap_toggled)
		
	if construction_system != null:
		construction_system.tool_changed.connect(_on_tool_changed)
		construction_system.wall_selected.connect(_on_wall_selected)
		construction_system.wall_deselected.connect(_on_wall_deselected)
		construction_system.wall_property_changed.connect(_on_wall_properties_synced)


func _on_modo_cambiado(_nuevo_modo) -> void:
	_update_visibility()


func _update_visibility() -> void:
	var can_edit: bool = AppManager.puede_editar()
	visible = can_edit


func _on_build_wall_pressed() -> void:
	if construction_system != null:
		construction_system.set_tool(ConstructionSystem.ConstructionTool.BUILD_WALL)
		_set_status("Herramienta: Construir Pared (Haz clic para punto inicial y final)")


func _on_select_pressed() -> void:
	if construction_system != null:
		construction_system.set_tool(ConstructionSystem.ConstructionTool.SELECT_WALL)
		_set_status("Herramienta: Seleccionar Pared (Haz clic en una pared)")


func _on_delete_pressed() -> void:
	if construction_system != null:
		construction_system.delete_selected_wall()


func _on_clear_all_pressed() -> void:
	if construction_system != null:
		construction_system.clear_all_walls()
		_set_status("Todas las paredes fueron eliminadas.")


func _on_dimensions_changed(_val: float) -> void:
	if construction_system != null and spin_height != null and spin_thickness != null:
		construction_system.set_wall_dimensions(spin_height.value, spin_thickness.value)


func _on_snap_toggled(button_pressed: bool) -> void:
	if construction_system != null and construction_system.grid_snapping != null:
		construction_system.grid_snapping.snap_enabled = button_pressed


func _on_snap_size_selected(index: int) -> void:
	var step := 1.0
	match index:
		0: step = 0.25
		1: step = 0.5
		2: step = 1.0
		3: step = 2.0
		
	if construction_system != null and construction_system.grid_snapping != null:
		construction_system.grid_snapping.grid_step = step


func _on_angle_snap_toggled(button_pressed: bool) -> void:
	if construction_system != null and construction_system.grid_snapping != null:
		construction_system.grid_snapping.angle_snap_enabled = button_pressed


func _on_tool_changed(tool_type: ConstructionSystem.ConstructionTool) -> void:
	if btn_build_wall != null:
		btn_build_wall.button_pressed = (tool_type == ConstructionSystem.ConstructionTool.BUILD_WALL)
	if btn_select != null:
		btn_select.button_pressed = (tool_type == ConstructionSystem.ConstructionTool.SELECT_WALL)


func _on_wall_selected(wall: Wall) -> void:
	if btn_delete != null:
		btn_delete.disabled = false
	_set_status("Pared seleccionada (%s). Modifica sus medidas o presiona SUPR para borrar." % wall.wall_id)


func _on_wall_deselected() -> void:
	if btn_delete != null:
		btn_delete.disabled = true
	_set_status("Listo.")


func _on_wall_properties_synced(height: float, thickness: float) -> void:
	if spin_height != null and not is_equal_approx(spin_height.value, height):
		spin_height.set_value_no_signal(height)
	if spin_thickness != null and not is_equal_approx(spin_thickness.value, thickness):
		spin_thickness.set_value_no_signal(thickness)


func _set_status(msg: String) -> void:
	if lbl_status != null:
		lbl_status.text = msg
