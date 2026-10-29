extends Node3D


@onready var modo_label: Label = $UI/ModoLabel


func _ready() -> void:
	AppManager.modo_cambiado.connect(_on_modo_cambiado)

	_actualizar_interfaz()

	print("Modo inicial: ", AppManager.obtener_nombre_modo())
	print("¿Puede editar?: ", AppManager.puede_editar())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode == KEY_C:
			AppManager.cambiar_modo(AppManager.Modo.CREAR)

		elif event.keycode == KEY_V:
			AppManager.cambiar_modo(AppManager.Modo.VISUALIZAR)


func _on_modo_cambiado(_nuevo_modo) -> void:
	_actualizar_interfaz()

	print("Modo actual: ", AppManager.obtener_nombre_modo())
	print("Herramientas habilitadas: ", EditorController.puede_usar_herramientas())


func _actualizar_interfaz() -> void:
	modo_label.text = AppManager.obtener_nombre_modo()


func _on_boton_visualizar_pressed() -> void:
	AppManager.cambiar_modo(AppManager.Modo.VISUALIZAR)


func _on_boton_crear_pressed() -> void:
	AppManager.cambiar_modo(AppManager.Modo.CREAR)
