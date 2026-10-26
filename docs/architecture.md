# Arquitectura

## Módulos

- `frontend/`: editor web React/Vite/Three.js. Se ejecuta de forma
  independiente y exporta escenas JSON.
- `backend/`: API FastAPI con SQLAlchemy. Gestiona recursos, miniaturas y
  proyectos; el almacenamiento binario permanece en disco.
- `godot/`: editor y visualizador 3D. Contiene las escenas de construcción y
  los autoloads `AppManager`, `EditorController` y `ProjectManager`.

## Flujo de integración

1. El frontend importa y transforma modelos GLB/glTF.
2. El backend registra los metadatos y almacena los archivos.
3. Godot consulta los recursos mediante `scripts/core/api.gd`.
4. Los proyectos pueden guardarse localmente en el formato compartido de
   `godot/data/formato_proyecto.json`.
