## Una obra de arte (imagen) colgada en una pared con soporte de formatos y marcos.
##
## Es un [StaticBody3D] con un plano texturizado, un marco 3D y una caja de colisión,
## para poder seleccionarla con un rayo del mouse.
## Capa de colisión 2 = obras (las paredes de la Persona 3 deben usar la capa 1).
class_name Artwork
extends StaticBody3D

## Formatos de proporción (aspect ratio).
const FORMATS = {
	"original": -1.0,
	"1:1": 1.0,
	"4:3": 4.0 / 3.0,
	"16:9": 16.0 / 9.0,
	"3:4": 3.0 / 4.0,
	"9:16": 9.0 / 16.0,
}

## Estilos y colores de marco.
const FRAME_STYLES = {
	"sin_marco": Color.TRANSPARENT,
	"madera": Color(0.42, 0.26, 0.15),
	"negro": Color(0.12, 0.12, 0.12),
	"blanco": Color(0.92, 0.92, 0.92),
	"dorado": Color(0.85, 0.70, 0.25),
}

## Ruta o URL de la imagen original (se guarda para poder recargarla).
var image_source := ""
## Ancho del cuadro en metros.
var width := 1.0
## Proporción ancho/alto de la imagen, para no deformarla.
var aspect := 1.0
## Proporción natural de la imagen cargada.
var original_aspect := 1.0
## Formato de proporción actual.
var current_format := "original"
## Estilo de marco actual.
var current_frame_style := "madera"

var _mesh: MeshInstance3D
var _frame_mesh: MeshInstance3D
var _shape: BoxShape3D
var _mat: StandardMaterial3D
var _frame_mat: StandardMaterial3D


func _init() -> void:
	add_to_group("artwork")
	collision_layer = 2  # esta obra vive en la capa 2
	collision_mask = 0   # no necesita detectar nada

	# Marco del cuadro
	_frame_mesh = MeshInstance3D.new()
	_frame_mesh.mesh = BoxMesh.new()
	_frame_mat = StandardMaterial3D.new()
	_frame_mat.roughness = 0.8
	_frame_mesh.material_override = _frame_mat
	add_child(_frame_mesh)

	# Lienzo / imagen de la obra
	_mesh = MeshInstance3D.new()
	_mesh.mesh = QuadMesh.new()
	_mesh.position.z = 0.016  # ligeramente por delante del marco
	add_child(_mesh)

	var col := CollisionShape3D.new()
	_shape = BoxShape3D.new()
	col.shape = _shape
	add_child(col)

	_mat = StandardMaterial3D.new()
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = _mat

	set_frame_style(current_frame_style)


## Asigna la imagen del cuadro. [param source] es su ruta o URL de origen.
func set_image(img: Image, source: String) -> void:
	image_source = source
	original_aspect = float(img.get_width()) / float(img.get_height())
	if current_format == "original" or not FORMATS.has(current_format):
		aspect = original_aspect
	else:
		aspect = FORMATS[current_format]
	_mat.albedo_texture = ImageTexture.create_from_image(img)
	_update_size()


## Cambia el ancho (limitado entre 0.2 y 6 m). El alto se calcula solo.
func set_width(w: float) -> void:
	width = clampf(w, 0.2, 6.0)
	_update_size()


## Cambia el formato de proporción del cuadro ("original", "1:1", "4:3", "16:9", "3:4", "9:16").
func set_format(fmt: String) -> void:
	current_format = fmt if FORMATS.has(fmt) else "original"
	if current_format == "original":
		aspect = original_aspect
	else:
		aspect = FORMATS[current_format]
	_update_size()


## Cambia el estilo del marco ("sin_marco", "madera", "negro", "blanco", "dorado").
func set_frame_style(style: String) -> void:
	current_frame_style = style if FRAME_STYLES.has(style) else "madera"
	if current_frame_style == "sin_marco":
		_frame_mesh.visible = false
	else:
		_frame_mesh.visible = true
		_frame_mat.albedo_color = FRAME_STYLES[current_frame_style]
		if current_frame_style == "dorado":
			_frame_mat.metallic = 0.7
			_frame_mat.roughness = 0.3
		else:
			_frame_mat.metallic = 0.0
			_frame_mat.roughness = 0.8
	_update_size()


## Resalta la obra (tono amarillo) cuando está seleccionada.
func set_highlight(on: bool) -> void:
	_mat.albedo_color = Color(1.0, 0.95, 0.6) if on else Color.WHITE


## Ajusta tamaño visual y colisión al ancho, proporción y marco actuales.
func _update_size() -> void:
	var h := width / aspect
	(_mesh.mesh as QuadMesh).size = Vector2(width, h)

	var border := 0.07 if current_frame_style != "sin_marco" else 0.0
	var fw := width + border * 2.0
	var fh := h + border * 2.0
	(_frame_mesh.mesh as BoxMesh).size = Vector3(fw, fh, 0.03)
	_shape.size = Vector3(fw, fh, 0.05)


## Convierte la obra a un [Dictionary] listo para guardarse en el proyecto (JSON).
func to_dict() -> Dictionary:
	return {
		"type": "artwork",
		"source": image_source,
		"position": [position.x, position.y, position.z],
		"rotation": [rotation.x, rotation.y, rotation.z],
		"width": width,
		"format": current_format,
		"frame_style": current_frame_style,
	}