# Modo administrador

El modo administrador permite consultar y gestionar todas las cuentas de
Galeris desde una interfaz web propia. Sustituye la necesidad de mirar la base
de datos a mano y añade control de roles y estados.

## Acceso

1. Inicia el backend (`uvicorn app.main:app --reload`).
2. Inicia el frontend (`npm run dev`).
3. Entra en `http://localhost:5173` con la cuenta administradora:

   | Usuario | Contraseña | Rol |
   | --- | --- | --- |
   | `admin` | `admin123` | Administrador |

La cuenta se crea automáticamente en el primer arranque. Puedes cambiarla con
`GALLERIS_ADMIN_USERNAME`, `GALLERIS_ADMIN_PASSWORD` y `GALLERIS_ADMIN_EMAIL`
antes de arrancar por primera vez.

Para la demostración con varios usuarios:

```powershell
cd backend
.venv\Scripts\python.exe seed_demo.py
```

Se crean seis cuentas (`laura`, `jenny`, `pau`, `marc`, `diego`, `lucia`) con la
contraseña `galeris123` y proyectos de ejemplo. `laura` es administradora y
`diego` está inactivo para probar los filtros.

## Qué incluye

- **Resumen general** con total de usuarios, administradores, cuentas activas e
  inactivas, proyectos y recursos.
- **Listado completo de usuarios** con nombre, usuario, correo, rol, estado,
  número de proyectos y recursos, y último acceso.
- **Búsqueda y filtros** por nombre/usuario/correo, rol y estado.
- **Ficha de usuario** con sus datos, sus proyectos y sus recursos.
- **Alta de usuarios** con rol y contraseña inicial.
- **Edición** de nombre, correo, rol, estado y contraseña.
- **Activación y desactivación** de cuentas. Una cuenta inactiva no puede
  iniciar sesión, aunque conserve sus datos.
- **Eliminación** de cuentas. Sus proyectos y recursos pasan a la galería
  general sin propietario.
- **Protecciones**: nadie puede quitarse su propio rol de administrador,
  desactivarse ni eliminarse a sí mismo, y siempre debe quedar al menos un
  administrador activo.

El administrador puede alternar entre el panel y el editor 3D con el botón
`Abrir editor 3D` / `Usuarios`.

## Autenticación

- Inicio de sesión mediante `POST /api/auth/login` con usuario o correo.
- Contraseñas guardadas con PBKDF2-HMAC-SHA256 (240 000 iteraciones y sal
  aleatoria).
- Sesiones mediante token firmado con HMAC-SHA256 y caducidad de 12 horas.
- El token se envía en `Authorization: Bearer <token>`.
- Cambiar la contraseña de una cuenta invalida sus sesiones anteriores.
- Los endpoints `/api/admin/*` devuelven `401` sin sesión y `403` si la cuenta
  no es administradora.
- Las peticiones sin sesión (por ejemplo, el cliente Godot local) conservan el
  comportamiento abierto de la API para no romper la integración existente. En
  un despliegue público conviene exigir token en todos los endpoints.

En producción, define `GALLERIS_SECRET_KEY` con un valor aleatorio y cambia la
contraseña inicial del administrador.

## Endpoints

| Método | Ruta | Descripción |
| --- | --- | --- |
| `POST` | `/api/auth/login` | Obtener token y datos del usuario |
| `GET` | `/api/auth/me` | Validar la sesión actual |
| `POST` | `/api/auth/logout` | Cerrar sesión en el cliente |
| `GET` | `/api/admin/stats` | Totales del panel |
| `GET` | `/api/admin/users?search=&role=&active=&limit=&offset=` | Listado paginado |
| `POST` | `/api/admin/users` | Crear usuario |
| `GET` | `/api/admin/users/{id}` | Ficha con proyectos y recursos |
| `PATCH` | `/api/admin/users/{id}` | Editar usuario |
| `DELETE` | `/api/admin/users/{id}` | Eliminar usuario |

Los recursos y proyectos guardados por una cuenta autenticada quedan asociados a
ella (`owner_id`). Un usuario solo ve los suyos; el administrador ve todos.

## Estructura del código

```text
backend/app/
├── bootstrap.py          # administrador inicial y datos de demostración
├── security.py           # hash de contraseñas, tokens y dependencias
├── models.py             # User, Resource y Project
├── schemas.py            # contratos de la API
└── routers/
    ├── auth.py           # login, me, logout
    └── admin.py          # usuarios, ficha y estadísticas

frontend/src/
├── App.jsx               # sesión y navegación panel/editor
├── api.js                # cliente HTTP y sesión en localStorage
├── Editor.jsx            # editor 3D existente + barra de sesión
└── components/
    ├── LoginScreen.jsx   # inicio de sesión
    └── AdminPanel.jsx    # panel de administración
```

## Pruebas

```powershell
cd backend
.venv\Scripts\python.exe -m pytest
```

`tests/test_admin.py` cubre login, permisos, alta/edición/eliminación de
usuarios, filtros, ficha con proyectos y las protecciones del último
administrador.
