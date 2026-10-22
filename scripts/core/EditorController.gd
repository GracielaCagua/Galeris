extends Node


func puede_usar_herramientas() -> bool:
	return AppMode.can_edit()

func bloquear_herramientas() -> void:
	return

func habilitar_herramientas() -> void:
	return

func verificar_permiso_edicion() -> bool:
	return AppMode.guard("editar")
