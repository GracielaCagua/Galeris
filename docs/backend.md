# Backend local

API FastAPI que guarda los metadatos en PostgreSQL y los archivos en carpetas.
Los archivos nunca se guardan en la base de datos: esta solo registra su ruta.

## Puesta en marcha

1. Prepara PostgreSQL con **una** de estas opciones:
   - **Ya instalado en la PC:**
     `psql -U postgres -f backend/scripts/setup_postgres.sql`
   - **Docker:** `docker compose up -d postgres`. Usa el puerto 5432, así que
     no puede convivir con un PostgreSQL local que ya ocupe ese puerto.
2. Inicia la API:

   ```powershell
   cd backend
   py -m venv .venv
   .venv\Scripts\Activate.ps1
   py -m pip install -r requirements.txt
   py -m uvicorn app.main:app --reload
   ```

La API usa `postgresql+psycopg://galeris:galeris@localhost:5432/galeris` si no se
configura otra cosa, y crea sus tablas al iniciar. Si no puede conectarse, se
detiene con un mensaje que indica a qué servidor intentó llegar.

Para comprobar la conexión: `GET http://127.0.0.1:8000/api/health/database`.
Documentación interactiva: `http://127.0.0.1:8000/docs`.

## Configuración

Copia `.env.example` a `.env` en la raíz del repositorio. Las credenciales de
ejemplo son solo para desarrollo local.

| Variable | Uso |
| --- | --- |
| `DATABASE_URL` | Conexión a la base de datos |
| `GALLERY_STORAGE_DIR` | Carpeta de los archivos (`./storage` por defecto) |

SQLite sigue funcionando con `DATABASE_URL=sqlite:///./data/gallery.db`, y es lo
que usan las pruebas. Los datos no se copian de un motor a otro.

## Endpoints

| Método | Ruta | Uso |
| --- | --- | --- |
| `GET` | `/api/health` | Estado de la API |
| `GET` | `/api/health/database` | Estado de la base de datos (503 si no responde) |
| `POST` | `/api/resources` | Subir un recurso |
| `GET` | `/api/resources` | Listar recursos (filtros `type` y `category`) |
| `GET` | `/api/resources/{id}` | Consultar un recurso |
| `GET` | `/api/resources/{id}/file` | Descargar el archivo |
| `GET` | `/api/resources/{id}/thumbnail` | Descargar la miniatura |
| `DELETE` | `/api/resources/{id}` | Eliminar un recurso y sus archivos |
| `POST` | `/api/projects` | Guardar un proyecto |
| `GET` | `/api/projects` | Listar proyectos |
| `GET` | `/api/projects/{id}` | Recuperar un proyecto |
| `PUT` | `/api/projects/{id}` | Actualizar un proyecto |
| `DELETE` | `/api/projects/{id}` | Eliminar un proyecto |

## Recursos

El campo `type` es opcional, porque se detecta por la extensión del archivo.

| `type` | Extensiones | Carpeta |
| --- | --- | --- |
| `image` | `.jpg`, `.jpeg`, `.png`, `.webp` | `storage/images/` |
| `model3d` | `.glb`, `.gltf` | `storage/models/` |
| `blender` | `.blend` | `storage/blender/` |

Las miniaturas son opcionales, deben ser imágenes y se guardan en
`storage/thumbnails/`.

```powershell
curl.exe -F "name=Escultura" -F "category=arte" -F "file=@escultura.glb" -F "thumbnail=@escultura.png" http://127.0.0.1:8000/api/resources
```

## Pruebas

```powershell
cd backend
py -m pip install -r requirements-dev.txt
py -m pytest
```

Usan SQLite temporal. Para ejecutarlas también contra PostgreSQL, define
`TEST_DATABASE_URL` con una base vacía **exclusiva para pruebas**, porque sus
tablas se borran después de cada prueba:

```powershell
$env:TEST_DATABASE_URL = "postgresql+psycopg://galeris:galeris@localhost:5432/galeris_test"
py -m pytest
```

## Cambios en las tablas

`create_all` solo crea tablas completas. Por eso, al iniciar, la API también añade
a las tablas existentes las columnas **opcionales** nuevas de los modelos. Un
cambio mayor (columnas obligatorias, renombrados, claves foráneas) necesita una
migración propia.

## Migración a la nube

Godot y el frontend solo conocen la API HTTP, así que migrar no los afecta:

- **Base de datos:** basta con apuntar `DATABASE_URL` al servidor en la nube y
  copiar los datos existentes.
- **Archivos:** hay que implementar el contrato `FileStorage` de
  `backend/app/storage.py` (`save`, `resolve` y `delete`) para el proveedor
  elegido y usarlo en `create_app`.
