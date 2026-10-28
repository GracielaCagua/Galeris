# Galeris

Galeris integra una interfaz web para gestionar modelos 3D, una API local para
recursos y proyectos, y un editor 3D desarrollado con Godot.

## Estructura

```text
Galeris/
├── frontend/   # React + Vite + Three.js
├── backend/    # FastAPI + SQLAlchemy + SQLite
├── godot/      # Editor y visualización 3D
└── docs/       # Documentación del proyecto
```

### Frontend

La aplicación React está en `frontend/`. Incluye carga de modelos GLB/glTF,
biblioteca de recursos, modos crear/visualizar, selección, transformaciones y
exportación de escenas JSON. `frontend/legacy/app.js` conserva la implementación
anterior basada en JavaScript plano.

```powershell
cd frontend
npm install
npm run dev
```

La aplicación estará disponible normalmente en `http://localhost:5173`.

### Backend

La API FastAPI está en `backend/` y persiste metadatos y proyectos con SQLite.
Los archivos se almacenan en disco.

```powershell
cd backend
py -m venv .venv
.venv\Scripts\Activate.ps1
py -m pip install -r requirements.txt
py -m uvicorn app.main:app --reload
```

La API queda disponible en `http://127.0.0.1:8000` y su documentación en
`http://127.0.0.1:8000/docs`.

Endpoints principales:

| Método | Ruta | Uso |
| --- | --- | --- |
| `GET` | `/api/health` | Estado de la API |
| `POST` / `GET` | `/api/resources` | Crear y listar recursos |
| `GET` | `/api/resources/{id}/file` | Descargar un recurso |
| `POST` / `GET` | `/api/projects` | Crear y listar proyectos |
| `PUT` / `DELETE` | `/api/projects/{id}` | Actualizar y eliminar proyectos |

Para ejecutar las pruebas:

```powershell
cd backend
py -m pip install -r requirements-dev.txt
py -m pytest
```

### Godot

El proyecto Godot está en `godot/`. Se conservaron las escenas y scripts del
sistema de construcción (paredes, suelos, cámara, cuadrícula y UI), junto con
los módulos de modos, control de edición y guardado de proyectos incorporados
desde `feature/godot`.

Abrir `godot/project.godot` desde el editor Godot 4.7 o posterior.

## Integración de datos

El formato de proyecto compartido se documenta en
`godot/data/formato_proyecto.json`. Godot guarda proyectos localmente mediante
`ProjectManager`; la API ofrece el almacenamiento remoto/local de recursos y
proyectos mediante HTTP.

El cliente Godot usa `http://127.0.0.1:8000` como URL base en
`godot/scripts/core/api.gd`. Inicia el backend antes de probar las funciones
que consultan recursos.
