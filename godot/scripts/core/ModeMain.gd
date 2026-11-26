extends Node3D

@onready var modo_label: Label = $UI/ModoLabel
@onready var cubo: MeshInstance3D = $World/Cubo/MeshInstance3D

var velocidad_movimiento: float = 2.0

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
		elif event.keycode == KEY_G:
			ProjectManager.guardar_escena($World/Objetos)
		elif event.keycode == KEY_L:
			var objetos = ProjectManager.cargar_datos_objetos()
			print("Datos listos para restaurar: ", objetos.size())
		elif event.keycode == KEY_K:
			ProjectManager.guardar_nodo_3d($World/Cubo)
		elif event.keycode == KEY_J:
			ProjectManager.restaurar_transformacion($World/Cubo)


func _process(delta: float) -> void:
	# En Modo Visualizar no se permite mover el cubo.
	if AppManager.esta_en_modo_visualizar():
		return

	# Las herramientas deben estar habilitadas en Modo Crear.
	if not EditorController.puede_usar_herramientas():
		return

	var movimiento := Vector3.ZERO

	if Input.is_key_pressed(KEY_LEFT):
		movimiento.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		movimiento.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		movimiento.z -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		movimiento.z += 1.0

	if movimiento != Vector3.ZERO:
		cubo.position += movimiento.normalized() * velocidad_movimiento * delta


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


func probar_guardado_carga() -> void:
	var datos_prueba: Dictionary = {
		"version": 1,
		"nombre_proyecto": "Prueba Facultad de Artes",
		"paredes": [
			{"id": "pared_1", "posicion": [0, 0, -2]}
		],
		"obras": [
			{"id": "obra_1", "nombre": "Obra de prueba"}
		],
		"objetos": [
			{
				"id": "objeto_1",
				"modelo": "cubo",
				"posicion": [1, 2, 3],
				"rotacion": [0, 0, 0],
				"escala": [1, 1, 1]
			}
		]
	}

	ProjectManager.guardar_proyecto(datos_prueba)

	var datos_cargados: Dictionary = ProjectManager.cargar_proyecto()

	if datos_cargados.is_empty():
		print("ERROR: No se recuperaron los datos.")
		return

	print("DATOS RECUPERADOS:")
	print(JSON.stringify(datos_cargados, "\t"))
	print("Nombre: ", datos_cargados.get("nombre_proyecto", "Sin nombre"))
	print("Cantidad de paredes: ", datos_cargados.get("paredes", []).size())
	print("Cantidad de obras: ", datos_cargados.get("obras", []).size())
	print("Cantidad de objetos: ", datos_cargados.get("objetos", []).size())
