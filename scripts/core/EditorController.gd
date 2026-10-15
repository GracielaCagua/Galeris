extends Node


var herramientas_habilitadas: bool = false


func _ready() -> void:
	AppManager.modo_cambiado.connect(_on_modo_cambiado)

	_actualizar_estado(AppManager.puede_editar())

	print("EDITOR 3D FACULTAD DE ARTES")
	print("Herramientas habilitadas: ", herramientas_habilitadas)


func _on_modo_cambiado(nuevo_modo) -> void:
	var puede_editar: bool = nuevo_modo == AppManager.Modo.CREAR

	_actualizar_estado(puede_editar)

	print("Cambio de modo")
	print("Herramientas habilitadas: ", herramientas_habilitadas)

func _actualizar_estado(puede_editar: bool) -> void:
	herramientas_habilitadas = puede_editar

func puede_usar_herramientas() -> bool:
	return herramientas_habilitadas

func bloquear_herramientas() -> void:
	herramientas_habilitadas = false

func habilitar_herramientas() -> void:
	if AppManager.puede_editar():
		herramientas_habilitadas = true

func verificar_permiso_edicion() -> bool:
	if not AppManager.puede_editar():
		print("Acción bloqueada: estás en Modo Visualizar.")
		return false

	return herramientas_habilitadas
