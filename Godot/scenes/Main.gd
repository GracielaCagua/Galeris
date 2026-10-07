extends Node3D


func _ready() -> void:
	print("=== PRUEBA DE ESTRUCTURA DEL PROYECTO ===")

	var proyecto: Dictionary = ProjectManager.crear_proyecto_vacio()

	print("Proyecto creado:")
	print(proyecto)

	print("Versión: ", proyecto["version"])
	print("Nombre: ", proyecto["nombre_proyecto"])
	print("Cantidad de paredes: ", proyecto["paredes"].size())
	print("Cantidad de obras: ", proyecto["obras"].size())
	print("Cantidad de objetos: ", proyecto["objetos"].size())
