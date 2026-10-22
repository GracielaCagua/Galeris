# Contrato de guardado local

## Alcance

El archivo JSON local de Godot es la fuente de verdad del proyecto. El backend
solo puede almacenar este documento como un blob; no debe definir ni transformar
otro esquema.

Este documento define el contrato compartido por:

- **P3:** paredes y piso.
- **P4:** modelos 3D.
- **P6:** cuadros.

La versión inicial del contrato es `1`.

## Documento raíz

```json
{
  "version": 1,
  "nombre_proyecto": "Galería Facultad de Artes",
  "recursos": {
    "modelos": {
      "modelo_cubo": "res://assets/modelos/cubo.glb"
    },
    "imagenes": {
      "cuadro_muestra": "res://assets/obras/cuadro_muestra.png"
    }
  },
  "paredes": [],
  "piso": {},
  "modelos": [],
  "cuadros": []
}
```

### Reglas del documento raíz

- `version` es obligatorio y debe ser un entero positivo.
- `nombre_proyecto` es opcional; si existe, es texto.
- `recursos` contiene catálogos de recursos por identificador estable.
- `paredes`, `piso`, `modelos` y `cuadros` pertenecen al mismo documento.
- Los módulos no deben guardar rutas de recursos directamente en sus entidades:
  deben referenciar un id definido en `recursos`.
- No se deben agregar campos alternativos para representar el mismo dato.

## Identificadores estables

Cada entidad persistible debe tener un `id` único dentro de su colección. El id:

- es texto;
- no cambia cuando cambia el nombre visible, la posición o el orden;
- debe asignarse al crear la entidad;
- se usa para actualizar, eliminar y relacionar entidades;
- no debe generarse a partir del nombre del nodo de Godot.

Ejemplos válidos: `pared_entrada`, `modelo_001`, `cuadro_luz_01`.

## Catálogo de recursos

Los recursos se declaran una vez en `recursos` y se referencian por id:

```json
{
  "recursos": {
    "modelos": {
      "modelo_cubo": "res://assets/modelos/cubo.glb"
    },
    "imagenes": {
      "cuadro_muestra": "res://assets/obras/cuadro_muestra.png"
    }
  }
}
```

El valor del catálogo es una ruta `res://` válida para Godot. Si un recurso no
puede resolverse, el consumidor debe informar el error y conservar el id
persistido; no debe sustituirlo silenciosamente por otro recurso.

## Entidades por módulo

### P3: paredes y piso

Cada elemento de `paredes` debe conservar su id y transformación:

```json
{
  "id": "pared_entrada",
  "posicion": [0.0, 1.5, -3.0],
  "rotacion": [0.0, 0.0, 0.0],
  "escala": [1.0, 1.0, 1.0],
  "dimensiones": [4.0, 3.0, 0.2]
}
```

`piso` usa el mismo formato de transformación y puede incluir
`dimensiones`. El piso es un objeto único, por lo que no requiere una
colección.

### P4: modelos 3D

Cada elemento de `modelos` debe contener:

```json
{
  "id": "modelo_001",
  "recurso_id": "modelo_cubo",
  "posicion": [1.0, 0.0, 1.0],
  "rotacion": [0.0, 0.0, 0.0],
  "escala": [1.0, 1.0, 1.0]
}
```

`recurso_id` debe existir en `recursos.modelos`.

### P6: cuadros

Cada elemento de `cuadros` debe contener:

```json
{
  "id": "cuadro_luz_01",
  "imagen_recurso_id": "cuadro_muestra",
  "pared_id": "pared_entrada",
  "posicion": [0.0, 1.8, -2.85],
  "rotacion": [0.0, 0.0, 0.0],
  "escala": [1.0, 1.0, 1.0]
}
```

- `imagen_recurso_id` debe existir en `recursos.imagenes`.
- `pared_id` debe referenciar una entidad existente en `paredes`.
- La posición, rotación y escala representan la transformación del cuadro
  respecto al espacio de la escena definido por P3.

## Interfaz común `persistible`

Todo nodo que participe en el documento debe pertenecer al grupo de Godot
`persistible`. El grupo identifica los nodos que pueden serializarse; no se
deben recorrer indiscriminadamente todos los hijos de la escena.

La interfaz mínima esperada es:

```gdscript
func serialize() -> Dictionary:
	return {
		"id": id,
		"posicion": [position.x, position.y, position.z],
		"rotacion": [rotation.x, rotation.y, rotation.z],
		"escala": [scale.x, scale.y, scale.z]
	}


func deserialize(data: Dictionary) -> void:
	position = Vector3(
		float(data["posicion"][0]),
		float(data["posicion"][1]),
		float(data["posicion"][2])
	)
	rotation = Vector3(
		float(data["rotacion"][0]),
		float(data["rotacion"][1]),
		float(data["rotacion"][2])
	)
	scale = Vector3(
		float(data["escala"][0]),
		float(data["escala"][1]),
		float(data["escala"][2])
	)
```

Cada módulo puede añadir sus campos propios, pero debe conservar `id` y los
campos comunes definidos para su entidad. `deserialize()` debe validar los
datos recibidos y notificar errores explícitamente; no debe inventar valores
para campos obligatorios.
