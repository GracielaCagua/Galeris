# Arquitectura

## Módulos

- `frontend/`: inicio de sesión, editor web React/Vite/Three.js y panel de
  administración. Se ejecuta de forma independiente y exporta escenas JSON.
- `backend/`: API FastAPI con SQLAlchemy. Gestiona usuarios, sesiones, recursos,
  miniaturas y proyectos; el almacenamiento binario permanece en disco.
- `godot/`: editor y visualizador 3D. Contiene las escenas de construcción y
  los autoloads `AppManager`, `EditorController` y `ProjectManager`.

## Autenticación y roles

El backend emite tokens HMAC firmados desde `/api/auth/login`. Existen dos
roles: `user` (editor y sus propios recursos) y `admin` (panel completo de
usuarios y acceso a todos los proyectos). Las rutas `/api/admin/*` exigen rol
administrador. El detalle del modo administrador está en
`docs/admin-mode.md`.

## Flujo de integración

1. El usuario inicia sesión y recibe un token de 12 horas.
2. El frontend importa y transforma modelos GLB/glTF.
3. El backend registra los metadatos y almacena los archivos, asociándolos al
   usuario que los sube.
4. El administrador consulta usuarios, roles, proyectos y recursos desde el
   panel web.
5. Godot consulta los recursos mediante `scripts/core/api.gd`.
6. Los proyectos pueden guardarse localmente en el formato compartido de
   `godot/data/formato_proyecto.json`.
