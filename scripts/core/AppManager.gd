extends Node

enum Modo {
	VISUALIZAR,
	CREAR
}

signal modo_cambiado(nuevo_modo)


func _ready() -> void:
	AppMode.mode_changed.connect(_on_mode_changed)


func cambiar_modo(nuevo_modo: Modo) -> void:
	AppMode.change_mode(_to_app_mode(nuevo_modo))


func esta_en_modo_visualizar() -> bool:
	return AppMode.is_visualizing()


func esta_en_modo_crear() -> bool:
	return AppMode.can_edit()


func obtener_nombre_modo() -> String:
	return AppMode.mode_name()


func puede_editar() -> bool:
	return AppMode.can_edit()


func _to_app_mode(modo: Modo):
	if modo == Modo.CREAR:
		return AppMode.Mode.CREATE

	return AppMode.Mode.VISUALIZE


func _on_mode_changed(mode) -> void:
	var legacy_mode: Modo = Modo.CREAR if mode == AppMode.Mode.CREATE else Modo.VISUALIZAR
	modo_cambiado.emit(legacy_mode)
