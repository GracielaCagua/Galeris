extends Node

const PROJECT_VERSION := 1
const PROJECT_DIRECTORY := "user://proyectos"
const DEFAULT_PROJECT_ID := "principal"


func create_empty_project() -> Dictionary:
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


func get_project_path(project_id: String = DEFAULT_PROJECT_ID) -> String:
	return "%s/%s.json" % [PROJECT_DIRECTORY, project_id]


func save_project(
	datos: Dictionary,
	project_id: String = DEFAULT_PROJECT_ID
) -> Dictionary:
	var documento := datos.duplicate(true)
	documento["version"] = PROJECT_VERSION

	var directory_path := ProjectSettings.globalize_path(PROJECT_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(directory_path)

	var project_path := get_project_path(project_id)
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


func load_project(project_id: String = DEFAULT_PROJECT_ID) -> Dictionary:
	var project_path := get_project_path(project_id)
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


func save_scene(container: Node = null, project_id: String = DEFAULT_PROJECT_ID) -> Dictionary:
	var load_result := load_project(project_id)
	var datos: Dictionary

	if load_result["ok"]:
		datos = load_result["datos"]
	elif load_result["mensaje"] == "no existe":
		datos = create_empty_project()
	else:
		return load_result

	var objetos: Array[Dictionary] = []
	var paredes: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("persistible"):
		if container != null and not container.is_ancestor_of(node):
			continue
		if not node.has_method("serialize"):
			push_error("El nodo persistible no implementa serialize(): " + node.name)
			continue

		var serialized = node.serialize()
		if serialized is Dictionary:
			if node.is_in_group("pared"):
				paredes.append(serialized)
			else:
				objetos.append(serialized)

	datos["objetos"] = objetos
	datos["paredes"] = paredes
	return save_project(datos, project_id)


func load_scene(container: Node, project_id: String = DEFAULT_PROJECT_ID) -> Dictionary:
	var result := load_project(project_id)
	if not result["ok"]:
		if result["mensaje"] == "no existe":
			return {"ok": true, "mensaje": "", "datos": create_empty_project()}
		return result

	var wall_script = load("res://scripts/core/Wall.gd")
	for child in container.get_children():
		if child.is_in_group("pared"):
			container.remove_child(child)
			child.queue_free()
	var walls = result["datos"].get("paredes", [])
	if not (walls is Array):
		return _error_result("la colección paredes debe ser una lista")
	for wall_data in walls:
		if not (wall_data is Dictionary):
			continue
		var wall: Node3D = wall_script.new()
		wall.name = "Pared_" + str(wall_data.get("id", "sin_id"))
		container.add_child(wall)
		wall.deserialize(wall_data)
	return result


func _error_result(message: String) -> Dictionary:
	return {
		"ok": false,
		"mensaje": message,
		"datos": {}
	}
