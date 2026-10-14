extends Node

const SAVE_PATH := "user://proyecto.json"
const PROJECT_VERSION := 1


func crear_proyecto_vacio() -> Dictionary:
	return {
		"version": PROJECT_VERSION,
		"nombre_proyecto": "Nuevo proyecto",
		"paredes": [],
		"obras": [],
		"objetos": []
	}

func guardar_proyecto(datos: Dictionary) -> void:
	var archivo = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

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
