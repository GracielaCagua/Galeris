class_name LienzoSala
extends Node3D
## Lienzo de la sala: piso de bloques y paredes externas con colisión.

@export var bloques_x: int = 3          ## bloques a lo ancho
@export var bloques_z: int = 5          ## bloques a lo largo
@export var tamano_bloque: float = 1.0  ## cada bloque mide 1 m
@export var alto_pared: float = 3.0
@export var grosor_pared: float = 0.2

func _ready() -> void:
	construir()

## Cambia el tamaño del lienzo y lo reconstruye.
func set_dimensiones(x: int, z: int) -> void:
	bloques_x = maxi(1, x)
	bloques_z = maxi(1, z)
	construir()

func construir() -> void:
	for hijo in get_children():
		remove_child(hijo)
		hijo.queue_free()
	_crear_piso()
	_crear_paredes()

func _crear_piso() -> void:
	var ancho := bloques_x * tamano_bloque
	var largo := bloques_z * tamano_bloque
	var grosor := 0.1

	var mat_a := StandardMaterial3D.new()
	mat_a.albedo_color = Color(0.85, 0.85, 0.85)
	var mat_b := StandardMaterial3D.new()
	mat_b.albedo_color = Color(0.7, 0.7, 0.7)

	# Un bloque visual por cada casilla (ajedrezado para ver la cuadrícula)
	for i in bloques_x:
		for j in bloques_z:
			var mesh := MeshInstance3D.new()
			var caja := BoxMesh.new()
			caja.size = Vector3(tamano_bloque, grosor, tamano_bloque)
			mesh.mesh = caja
			mesh.material_override = mat_a if (i + j) % 2 == 0 else mat_b
			mesh.position = Vector3(
				(i + 0.5) * tamano_bloque - ancho / 2.0,
				-grosor / 2.0,
				(j + 0.5) * tamano_bloque - largo / 2.0
			)
			add_child(mesh)

	# Colisión del piso (una sola pieza)
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "PisoColision"
	var forma := CollisionShape3D.new()
	var caja_col := BoxShape3D.new()
	caja_col.size = Vector3(ancho, grosor, largo)
	forma.shape = caja_col
	cuerpo.position = Vector3(0.0, -grosor / 2.0, 0.0)
	cuerpo.add_child(forma)
	add_child(cuerpo)

func _crear_paredes() -> void:
	var ancho := bloques_x * tamano_bloque
	var largo := bloques_z * tamano_bloque
	var g := grosor_pared
	var h := alto_pared

	# Norte y Sur (cubren las esquinas)
	_crear_pared("ParedNorte", Vector3(0.0, h / 2.0, -largo / 2.0 - g / 2.0), Vector3(ancho + 2.0 * g, h, g))
	_crear_pared("ParedSur", Vector3(0.0, h / 2.0, largo / 2.0 + g / 2.0), Vector3(ancho + 2.0 * g, h, g))
	# Oeste y Este
	_crear_pared("ParedOeste", Vector3(-ancho / 2.0 - g / 2.0, h / 2.0, 0.0), Vector3(g, h, largo))
	_crear_pared("ParedEste", Vector3(ancho / 2.0 + g / 2.0, h / 2.0, 0.0), Vector3(g, h, largo))

func _crear_pared(nombre: String, centro: Vector3, tamano: Vector3) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.position = centro

	var mesh := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tamano
	mesh.mesh = caja
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.9)
	mesh.material_override = mat
	cuerpo.add_child(mesh)

	var forma := CollisionShape3D.new()
	var caja_col := BoxShape3D.new()
	caja_col.size = tamano
	forma.shape = caja_col
	cuerpo.add_child(forma)

	add_child(cuerpo)