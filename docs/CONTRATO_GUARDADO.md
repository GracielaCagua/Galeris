# Contrato de guardado local

El JSON local de Godot es la fuente de verdad del proyecto. El backend solo
guarda este documento como un blob y no define un esquema alternativo.

La API de código usa nombres en inglés. Las claves persistidas del JSON usan
nombres en español. La versión actual del contrato es `1`.

## Documento raíz

```json
{
  "version": 1,
  "nombre_proyecto": "Galería Facultad de Artes",
  "recursos": {
    "imagenes": {
      "obra_luz": "identificador-de-recurso-de-imagen"
    },
    "modelos": {
      "escultura_01": "identificador-de-recurso-de-modelo"
    }
  },
  "paredes": [
    {
      "id": "pared_entrada",
      "inicio": [0.0, -3.0],
      "fin": [4.0, -3.0],
      "alto": 3.0,
      "grosor": 0.2
    }
  ],
  "piso": {
    "id": "piso_principal",
    "dimensiones": [10.0, 10.0]
  },
  "obras": [
    {
      "id": "obra_01",
      "imagen_id": "obra_luz",
      "pared_id": "pared_entrada",
      "posicion": [2.0, 1.5, -2.85],
      "rotacion": [0.0, 0.0, 0.0],
      "escala": [1.0, 1.0, 1.0]
    }
  ],
  "objetos": [
    {
      "id": "objeto_01",
      "modelo_id": "escultura_01",
      "posicion": [1.0, 0.0, 1.0],
      "rotacion": [0.0, 0.0, 0.0],
      "escala": [1.0, 1.0, 1.0]
    }
  ]
}
```

`recursos` contiene identificadores estables. Sus valores son referencias
opacas administradas por el catálogo de recursos; las entidades no deben
guardar rutas `res://`. Un consumidor resuelve el recurso mediante su id.

## Entidades

- `paredes`: pertenece a P3. `inicio` y `fin` son puntos `[x, z]`; `alto` y
  `grosor` son números positivos.
- `piso`: pertenece a P3. `dimensiones` es `[ancho, profundidad]`.
- `obras`: pertenece a P6. `imagen_id` referencia `recursos.imagenes` y
  `pared_id` referencia una pared.
- `objetos`: pertenece a P4. `modelo_id` referencia `recursos.modelos`.
- `posicion`, `rotacion` y `escala` usan `[x, y, z]`.
- `rotacion` se expresa en radianes usando ángulos de Euler.
- Cada `id` es texto, único dentro de su colección y estable durante toda la
  vida de la entidad. Nunca se deriva de `Node.name`.

Las claves desconocidas deben conservarse al leer, actualizar y volver a
escribir el documento. No se permite reconstruir el documento con una lista
blanca que elimine campos pertenecientes a futuras versiones o a otros
módulos.

## Interfaz `persistible`

Todo nodo que participe en el documento debe pertenecer al grupo Godot
`persistible`. La interfaz de código es en inglés y cada nodo debe implementar
`serialize() -> Dictionary` y `deserialize(data: Dictionary)`. El `id`
persistido es estable y distinto de `node.name`.

Ejemplo mínimo:

```gdscript
extends Node3D

var id: String = "objeto_01"

func _ready() -> void:
	add_to_group("persistible")

func serialize() -> Dictionary:
	return {
		"id": id,
		"posicion": [position.x, position.y, position.z],
		"rotacion": [rotation.x, rotation.y, rotation.z],
		"escala": [scale.x, scale.y, scale.z]
	}

func deserialize(data: Dictionary) -> void:
	id = str(data["id"])
	position = Vector3(data["posicion"][0], data["posicion"][1], data["posicion"][2])
	rotation = Vector3(data["rotacion"][0], data["rotacion"][1], data["rotacion"][2])
	scale = Vector3(data["escala"][0], data["escala"][1], data["escala"][2])
```

`deserialize()` debe validar campos obligatorios y reportar errores
explícitamente. La Entrega A no instancia nodos a partir del JSON; esa carga
pertenece a la Entrega B.
