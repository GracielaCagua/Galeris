extends Node

signal mode_changed(mode: Mode)

enum Mode {
	VISUALIZE,
	CREATE
}

var current_mode: Mode = Mode.VISUALIZE


func change_mode(new_mode: Mode) -> void:
	if current_mode == new_mode:
		return

	current_mode = new_mode
	_update_editor_tools()
	mode_changed.emit(current_mode)


func can_edit() -> bool:
	return current_mode == Mode.CREATE


func guard(action: String) -> bool:
	if can_edit():
		return true

	print("Acción bloqueada en Modo Visualizar: ", action)
	return false


func is_visualizing() -> bool:
	return current_mode == Mode.VISUALIZE


func mode_name() -> String:
	if is_visualizing():
		return "Modo Visualizar"

	return "Modo Crear"


func _update_editor_tools() -> void:
	var enabled := can_edit()
	for node in get_tree().get_nodes_in_group("editor_tool"):
		node.set_process(enabled)
		node.set_physics_process(enabled)
		node.set_process_unhandled_input(enabled)
