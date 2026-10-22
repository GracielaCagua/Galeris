extends Node3D

@onready var modo_label: Label = $UI/ModoLabel

func _ready() -> void:
	AppMode.mode_changed.connect(_on_mode_changed)

	_actualizar_interfaz()

	print("Modo inicial: ", AppMode.mode_name())
	print("¿Puede editar?: ", AppMode.can_edit())

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			AppMode.change_mode(AppMode.Mode.CREATE)
		elif event.keycode == KEY_V:
			AppMode.change_mode(AppMode.Mode.VISUALIZE)


func _on_mode_changed(_new_mode) -> void:
	_actualizar_interfaz()

	print("Modo actual: ", AppMode.mode_name())


func _actualizar_interfaz() -> void:
	modo_label.text = AppMode.mode_name()

