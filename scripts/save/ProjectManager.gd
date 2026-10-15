extends Node

const SAVE_PATH := "user://proyecto.json"
const PROJECT_VERSION := 1



func crear_proyecto_vacio() -> Dictionary:
	return {
		"version": 1,
		"nombre_proyecto": "Nuevo proyecto",
		"paredes": [],
		"obras": [],
		"objetos": []
	}


func guardar_proyecto(datos: Dictionary) -> void:
	var archivo = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	print("Ruta del archivo guardado: ", ProjectSettings.globalize_path(SAVE_PATH))

	if archivo == null:
		print("ERROR: No se pudo abrir el archivo para guardar.")
		return

	archivo.store_string(JSON.stringify(datos))
	archivo.close()

	print("Proyecto guardado correctamente.")


func cargar_proyecto() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No existe un proyecto guardado.")
		return {}

	var archivo = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if archivo == null:
		print("ERROR: No se pudo abrir el archivo guardado.")
		return {}

	var contenido = archivo.get_as_text()
	archivo.close()

	var datos = JSON.parse_string(contenido)

	if datos is Dictionary:
		print("Proyecto cargado correctamente.")
		return datos

	print("ERROR: El archivo no contiene datos válidos.")
	return {}


func obtener_datos_objetos(contenedor: Node3D) -> Array[Dictionary]:
	var objetos_guardados: Array[Dictionary] = []

	for objeto in contenedor.get_children():
		if not objeto is Node3D:
			continue

		var datos: Dictionary = {
			"id": str(objeto.name),
			"posicion": [
				objeto.position.x,
				objeto.position.y,
				objeto.position.z
			],
			"rotacion": [
				objeto.rotation.x,
				objeto.rotation.y,
				objeto.rotation.z
			],
			"escala": [
				objeto.scale.x,
				objeto.scale.y,
				objeto.scale.z
			]
		}

		objetos_guardados.append(datos)

	return objetos_guardados


func guardar_escena(contenedor: Node3D) -> void:
	var datos: Dictionary = crear_proyecto_vacio()

	datos["nombre_proyecto"] = "Galería Facultad de Artes"
	datos["objetos"] = obtener_datos_objetos(contenedor)

	guardar_proyecto(datos)

	print("Objetos guardados: ", datos["objetos"].size())


func cargar_datos_objetos() -> Array:
	var datos: Dictionary = cargar_proyecto()

	if datos.is_empty():
		print("No hay datos de proyecto para cargar.")
		return []

	var objetos: Array = datos.get("objetos", [])
	print("Objetos recuperados: ", objetos.size())

	return objetos


func guardar_nodo_3d(objeto: Node3D) -> void:
	var datos: Dictionary = crear_proyecto_vacio()

	datos["nombre_proyecto"] = "Galería Facultad de Artes"
	datos["objetos"] = [
		{
			"id": str(objeto.name),
			"modelo": "cubo",
			"posicion": [
				objeto.position.x,
				objeto.position.y,
				objeto.position.z
			],
			"rotacion": [
				objeto.rotation.x,
				objeto.rotation.y,
				objeto.rotation.z
			],
			"escala": [
				objeto.scale.x,
				objeto.scale.y,
				objeto.scale.z
			]
		}
	]

	guardar_proyecto(datos)
	print("Nodo guardado: ", objeto.name)


func restaurar_transformacion(objeto: Node3D) -> bool:
	var datos: Dictionary = cargar_proyecto()
	var objetos: Array = datos.get("objetos", [])

	for item in objetos:
		if str(item.get("id", "")) != str(objeto.name):
			continue

		var posicion: Array = item.get("posicion", [])
		var rotacion: Array = item.get("rotacion", [])
		var escala: Array = item.get("escala", [])

		if posicion.size() != 3 or rotacion.size() != 3 or escala.size() != 3:
			print("ERROR: Transformación incompleta.")
			return false

		objeto.position = Vector3(
			float(posicion[0]), float(posicion[1]), float(posicion[2])
		)
		objeto.rotation = Vector3(
			float(rotacion[0]), float(rotacion[1]), float(rotacion[2])
		)
		objeto.scale = Vector3(
			float(escala[0]), float(escala[1]), float(escala[2])
		)

		print("Transformación restaurada: ", objeto.name)
		return true

	print("No se encontró el objeto: ", objeto.name)
	return false



func guardar_proyecto_completo(datos: Dictionary) -> bool:
	var proyecto: Dictionary = crear_proyecto_vacio()

	proyecto["nombre_proyecto"] = datos.get(
		"nombre_proyecto",
		"Nuevo proyecto"
	)

	proyecto["paredes"] = datos.get("paredes", [])
	proyecto["obras"] = datos.get("obras", [])
	proyecto["objetos"] = datos.get("objetos", [])

	var archivo := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if archivo == null:
		push_error("No se pudo abrir el archivo para guardar.")
		return false

	archivo.store_string(JSON.stringify(proyecto, "\t"))
	archivo.close()

	print("Proyecto completo guardado correctamente.")
	return true
	
	
func probar_guardado_completo() -> void:
	var datos: Dictionary = {
		"nombre_proyecto": "Prueba de integración",
		"paredes": [{"id": "pared_1"}],
		"obras": [{"id": "obra_1"}],
		"objetos": [{"id": "objeto_1"}]
	}

	if guardar_proyecto_completo(datos):
		var recuperado := cargar_proyecto()

		print("Paredes recuperadas: ", recuperado.get("paredes", []).size())
		print("Obras recuperadas: ", recuperado.get("obras", []).size())
		print("Objetos recuperados: ", recuperado.get("objetos", []).size())
