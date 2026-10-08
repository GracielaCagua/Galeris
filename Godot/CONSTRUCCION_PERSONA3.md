# Módulo de Construcción y Modo Crear — Persona 3

Este módulo implementa el sistema de construcción de espacios arquitectónicos y herramientas exclusivas del **Modo Crear** para el Editor 3D de la Facultad de Artes.

---

## 📁 Estructura de Archivos Creados

```text
Godot/
├── scenes/
│   └── construction/
│       ├── Wall.tscn                # Escena de pared 3D con colisión y material dinámico
│       ├── Floor.tscn               # Piso base de la galería con colisión física
│       ├── ConstructionUI.tscn      # Interfaz gráfica de herramientas de edición
│       └── ConstructionSystem.tscn  # Sistema central que orquesta la construcción
└── scripts/
    └── construction/
        ├── Wall.gd                  # Lógica de pared (geometría, colisión, serialización)
        ├── Floor.gd                 # Lógica de piso base (dimensiones, colisión)
        ├── GridSnapping.gd          # Snapping espacial, angular y cuadrícula visual
        ├── EditorCamera.gd          # Cámara orbital/pan/zoom para el Modo Crear
        ├── ConstructionUI.gd        # Controlador de la UI del constructor
        └── ConstructionSystem.gd    # Administrador principal del sistema de construcción
```

---

## 🧱 Características Implementadas

1. **Herramientas exclusivas del Modo Crear**:
   - Se activan/desactivan automáticamente según `AppManager.modo_actual` y `AppManager.puede_editar()`.
   - En **Modo Visualizar**, la interfaz, cuadrícula visual, cámara orbital y herramientas de edición quedan completamente ocultas y desactivadas, garantizando que el usuario no pueda alterar la escena por accidente.

2. **Creación de paredes por punto inicial y final**:
   - **Primer clic**: fija el punto inicial (alineado a la cuadrícula según snapping).
   - **Movimiento del mouse**: muestra una previsualización de la pared en tiempo real.
   - **Segundo clic**: genera la pared con `StaticBody3D` y `CollisionShape3D` para las colisiones físicas.
   - **Encadenamiento**: permite seguir construyendo paredes continuas.

3. **Selección, movimiento y eliminación de paredes**:
   - Herramienta de Selección para hacer clic sobre cualquier pared existente.
   - Resaltado visual en color azul luminoso al seleccionarla.
   - Tecla **Supr / Backspace** o botón en UI para eliminar la pared seleccionada.
   - Botón para limpiar todas las paredes.

4. **Piso Base para espacios expositivos**:
   - Objeto `Floor` configurable (por defecto 40m x 40m) en nivel $Y = 0$, con colisión para que el jugador de Persona 2 camine sobre él.

5. **Cuadrícula y Sistema de Snapping**:
   - Snapping configurable a **0.25m, 0.50m, 1.00m o 2.00m**.
   - Snapping angular a **45° y 90°** para crear esquinas rectas y paredes ortogonales precisas.
   - Cuadrícula visual 3D generada dinámicamente en el suelo.

6. **Medidas configurables de pared**:
   - Alto configurable (por defecto **3.0m**).
   - Grosor configurable (por defecto **0.2m**).
   - Longitud calculada dinámicamente según la distancia entre puntos.

---

## 🤝 Coordinación con Persona 1 (Guardado y Carga de Proyectos)

El formato JSON compatible con `ProjectManager.gd` es el siguiente:

### Formato de Guardado de Paredes:
```json
{
  "version": 1,
  "nombre_proyecto": "Galería de Artes",
  "paredes": [
    {
      "id": "wall_1712345678_123",
      "start": [0.0, 0.0, 0.0],
      "end": [5.0, 0.0, 0.0],
      "height": 3.0,
      "thickness": 0.2
    },
    {
      "id": "wall_1712345679_456",
      "start": [5.0, 0.0, 0.0],
      "end": [5.0, 0.0, 8.0],
      "height": 3.0,
      "thickness": 0.2
    }
  ],
  "obras": [],
  "objetos": []
}
```

### Métodos para Persona 1:
```gdscript
# Obtener todas las paredes para guardar en el archivo JSON
var datos_paredes = $ConstructionSystem.get_walls_data()

# Cargar las paredes desde el archivo JSON del proyecto
$ConstructionSystem.load_walls_from_data(datos_cargados["paredes"])
```

---

## 🚶 Coordinación con Persona 2 (Modo Visualizar y Colisiones)

- Cada pared y el piso base cuentan con `StaticBody3D` en la capa de colisión 1 (`collision_layer = 1`).
- La cámara de edición `EditorCamera` se desactiva automáticamente en Modo Visualizar para ceder el control a la cámara en primera persona de Persona 2.
