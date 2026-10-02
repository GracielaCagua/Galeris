# Galeris

Backend local para la galería de recursos de Galeris. La API está hecha con FastAPI; SQLite guarda metadatos y proyectos, mientras que los archivos se guardan en disco.

## 1. Preparar el entorno

Requiere Python 3.10 o posterior. Desde la raíz del repositorio:

```powershell
cd backend
py -m venv .venv
.venv\Scripts\Activate.ps1
py -m pip install -r requirements.txt
```

## 2. Iniciar la API

```powershell
py -m uvicorn app.main:app --reload
```

La API queda en `http://127.0.0.1:8000`; la documentación interactiva está en `http://127.0.0.1:8000/docs`. La primera ejecución crea `backend/data/gallery.db` y las carpetas `backend/storage/resources` y `backend/storage/thumbnails`.

Se pueden cambiar las ubicaciones mediante `DATABASE_URL` y `GALLERY_STORAGE_DIR`. La URL predeterminada de base de datos es `sqlite:///./data/gallery.db` (relativa a `backend`).

## 3. Endpoints

| Método | Ruta | Uso |
| --- | --- | --- |
| `POST` | `/api/resources` | Subir un archivo y, opcionalmente, su miniatura (`multipart/form-data`: `file`, `name`, `type`, `category`, `thumbnail`). |
| `GET` | `/api/resources` | Listar recursos; admite filtros `type` y `category`. |
| `GET` | `/api/resources/{id}` | Consultar los metadatos de un recurso. |
| `GET` | `/api/resources/{id}/file` | Descargar el archivo original. |
| `GET` | `/api/resources/{id}/thumbnail` | Obtener su miniatura, si existe. |
| `DELETE` | `/api/resources/{id}` | Eliminar metadatos y archivos del almacenamiento local. |
| `POST` | `/api/projects` | Guardar un proyecto JSON. |
| `GET` | `/api/projects` | Listar proyectos. |
| `GET` | `/api/projects/{id}` | Recuperar un proyecto. |
| `PUT` | `/api/projects/{id}` | Actualizar un proyecto. |
| `DELETE` | `/api/projects/{id}` | Eliminar un proyecto. |

Los metadatos incluyen nombre, tipo, categoría, ruta de almacenamiento, ruta de miniatura y fecha de creación. SQLite no contiene los bytes de los archivos. Las respuestas también incluyen URLs HTTP para que Godot pueda descargar los recursos.

## 4. Conectar Godot

Añade un nodo `HTTPRequest` a la escena y asígnalo a `$HTTPRequest`. Este ejemplo lista recursos y muestra sus nombres:

```gdscript
extends Node

const API_URL := "http://127.0.0.1:8000/api/resources"

func _ready() -> void:
	$HTTPRequest.request_completed.connect(_on_resources_loaded)
	var error := $HTTPRequest.request(API_URL)
	if error != OK:
		push_error("No se pudo iniciar la petición a Galeris: %s" % error)

func _on_resources_loaded(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_error("Error al consultar recursos. HTTP %s" % code)
		return
	var resources: Array = JSON.parse_string(body.get_string_from_utf8())
	for resource in resources:
		print(resource["name"], " -> ", resource["file_url"])
```

Para descargar el archivo, usa otra petición `HTTPRequest` con el `file_url` devuelto por la API. Dentro del juego conviene guardar la URL base en un único autoload/configuración para poder cambiarla sin tocar las escenas.

## 5. Ejecutar las pruebas

Desde `backend`:

```powershell
py -m pip install -r requirements-dev.txt
py -m pytest
```

## Estructura y migración

- `app/models.py` define los metadatos persistidos.
- `app/database.py` centraliza el motor y las sesiones SQLAlchemy; `DATABASE_URL` permite cambiar el motor compatible sin alterar los endpoints.
- `app/storage.py` contiene el adaptador de archivos local; la API depende de esa interfaz y no de rutas de disco directas.
- `app/routers/` contiene los endpoints de recursos y proyectos.

En una migración futura se sustituye el adaptador de almacenamiento por uno de objetos en la nube y se cambia la URL del motor/base de datos, manteniendo el contrato HTTP de Godot. Para entornos multiusuario habrá que añadir autenticación, límites de subida y una migración de esquema gestionada antes de exponer el servicio fuera del equipo local.
