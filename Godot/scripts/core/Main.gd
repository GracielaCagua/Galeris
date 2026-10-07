extends Node3D


func _ready() -> void:
	print("EDITOR 3D FACULTAD DE ARTES")
	print("Modo inicial: ", AppManager.obtener_nombre_modo())
	print("¿Puede editar?: ", AppManager.puede_editar())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode == KEY_C:
			AppManager.cambiar_modo(AppManager.Modo.CREAR)
			print("Modo actual: ", AppManager.obtener_nombre_modo())

		elif event.keycode == KEY_V:
			AppManager.cambiar_modo(AppManager.Modo.VISUALIZAR)
			print("Modo actual: ", AppManager.obtener_nombre_modo())
