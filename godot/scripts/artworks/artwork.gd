## Una obra de arte (imagen) colgada en una pared.
##
## Es un [StaticBody3D] con un plano texturizado y una caja de colisión,
## para poder seleccionarla con un rayo del mouse.
## Capa de colisión 2 = obras (las paredes de la Persona 3 deben usar la capa 1).
class_name Artwork
extends StaticBody3D

## Ruta o URL de la imagen original (se guarda para poder recargarla).
var image_source := ""
## Ancho del cuadro en metros.
var width := 1.0
## Proporción ancho/alto de la imagen, para no deformarla.
var aspect := 1.0

var _mesh: MeshInstance3D
var _shape: BoxShape3D
var _mat: StandardMaterial3D


func _init() -> void:
	add_to_group("artwork")
	collision_layer = 2  # esta obra vive en la capa 2
	collision_mask = 0   # no necesita detectar nada

	_mesh = MeshInstance3D.new()
	_mesh.mesh = QuadMesh.new()
	add_child(_mesh)

	var col := CollisionShape3D.new()
	_shape = BoxShape3D.new()
	col.shape = _shape
	add_child(col)

	_mat = StandardMaterial3D.new()
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED                  # visible por ambos lados
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED       # colores fieles, sin sombras
	_mesh.material_override = _mat


## Asigna la imagen del cuadro. [param source] es su ruta o URL de origen.
func set_image(img: Image, source: String) -> void:
	image_source = source
	aspect = float(img.get_width()) / float(img.get_height())
	_mat.albedo_texture = ImageTexture.create_from_image(img)
	_update_size()


## Cambia el ancho (limitado entre 0.2 y 6 m). El alto se calcula solo.
func set_width(w: float) -> void:
	width = clampf(w, 0.2, 6.0)
	_update_size()


## Resalta la obra (tono amarillo) cuando está seleccionada.
func set_highlight(on: bool) -> void:
	_mat.albedo_color = Color(1.0, 0.95, 0.6) if on else Color.WHITE


## Ajusta tamaño visual y colisión al ancho y proporción actuales.
func _update_size() -> void:
	var h := width / aspect
	(_mesh.mesh as QuadMesh).size = Vector2(width, h)
	_shape.size = Vector3(width, h, 0.05)


## Convierte la obra a un [Dictionary] listo para guardarse en el proyecto (JSON).
## Formato a acordar con la Persona 1.
func to_dict() -> Dictionary:
	return {
		"type": "artwork",
		"source": image_source,
		"position": [position.x, position.y, position.z],
		"rotation": [rotation.x, rotation.y, rotation.z],
		"width": width,
	}