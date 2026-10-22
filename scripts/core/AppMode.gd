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
	mode_changed.emit(current_mode)


func can_edit() -> bool:
	return current_mode == Mode.CREATE


func can_use_tools() -> bool:
	return can_edit()


func is_visualizing() -> bool:
	return current_mode == Mode.VISUALIZE


func mode_name() -> String:
	if is_visualizing():
		return "Modo Visualizar"

	return "Modo Crear"
