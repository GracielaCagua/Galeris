extends Node

const PROJECT_VERSION := 1
const PROJECT_DIRECTORY := "user://proyectos"
const DEFAULT_PROJECT_ID := "principal"


func crear_proyecto_vacio() -> Dictionary:
	return {
		"version": PROJECT_VERSION,
		"nombre_proyecto": "Nuevo proyecto",
		"recursos": {
			"imagenes": {},
			"modelos": {}
		},
		"paredes": [],
		"piso": {},
		"obras": [],
		"objetos": []
	}


func obtener_ruta_proyecto(project_id: String = DEFAULT_PROJECT_ID) -> String:
	return "%s/%s.json" % [PROJECT_DIRECTORY, project_id]


func guardar_proyecto(
	datos: Dictionary,
	project_id: String = DEFAULT_PROJECT_ID
) -> Dictionary:
	var documento := datos.duplicate(true)
	documento["version"] = PROJECT_VERSION

	var directory_path := ProjectSettings.globalize_path(PROJECT_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(directory_path)

	var project_path := obtener_ruta_proyecto(project_id)
	var temporary_path := project_path + ".tmp"
	var temporary_file := FileAccess.open(temporary_path, FileAccess.WRITE)

	if temporary_file == null:
		return _error_result("no se pudo abrir el archivo temporal")

	temporary_file.store_string(JSON.stringify(documento, "\t"))
	temporary_file.flush()
	temporary_file.close()

	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(project_path)
	)
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return _error_result("no se pudo reemplazar el archivo del proyecto")

	return {
		"ok": true,
		"mensaje": "",
		"datos": documento
	}


func cargar_proyecto(project_id: String = DEFAULT_PROJECT_ID) -> Dictionary:
	var project_path := obtener_ruta_proyecto(project_id)
	if not FileAccess.file_exists(project_path):
		return _error_result("no existe")

	var project_file := FileAccess.open(project_path, FileAccess.READ)
	if project_file == null:
		return _error_result("no se pudo abrir el archivo del proyecto")

	var parsed_data = JSON.parse_string(project_file.get_as_text())
	project_file.close()

	if not (parsed_data is Dictionary):
		return _error_result("JSON inválido")

	if parsed_data.get("version") != PROJECT_VERSION:
		return _error_result("versión no soportada")

	return {
		"ok": true,
		"mensaje": "",
		"datos": parsed_data
	}


func guardar_escena(contenedor: Node = null, project_id: String = DEFAULT_PROJECT_ID) -> Dictionary:
	var load_result := cargar_proyecto(project_id)
	var datos: Dictionary

	if load_result["ok"]:
		datos = load_result["datos"]
	elif load_result["mensaje"] == "no existe":
		datos = crear_proyecto_vacio()
	else:
		return load_result

	var objetos: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("persistible"):
		if contenedor != null and not contenedor.is_ancestor_of(node):
			continue
		if not node.has_method("serialize"):
			push_error("El nodo persistible no implementa serialize(): " + node.name)
			continue

		var serialized = node.serialize()
		if serialized is Dictionary:
			objetos.append(serialized)

	datos["objetos"] = objetos
	return guardar_proyecto(datos, project_id)


func _error_result(message: String) -> Dictionary:
	return {
		"ok": false,
		"mensaje": message,
		"datos": {}
	}
