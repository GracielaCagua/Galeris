extends Node


var herramientas_habilitadas: bool = false


func _ready() -> void:
	AppMode.mode_changed.connect(_on_mode_changed)

	_actualizar_estado(AppMode.can_edit())

	print("EDITOR 3D FACULTAD DE ARTES")
	print("Herramientas habilitadas: ", herramientas_habilitadas)


func _on_mode_changed(_new_mode: AppMode.Mode) -> void:
	_actualizar_estado(AppMode.can_use_tools())

	print("Cambio de modo")
	print("Herramientas habilitadas: ", herramientas_habilitadas)

func _actualizar_estado(puede_editar: bool) -> void:
	herramientas_habilitadas = puede_editar

func puede_usar_herramientas() -> bool:
	return herramientas_habilitadas

func bloquear_herramientas() -> void:
	herramientas_habilitadas = false

func habilitar_herramientas() -> void:
	if AppMode.can_edit():
		herramientas_habilitadas = true

func verificar_permiso_edicion() -> bool:
	if not AppMode.can_edit():
		print("Acción bloqueada: estás en Modo Visualizar.")
		return false

	return herramientas_habilitadas and AppMode.can_use_tools()
