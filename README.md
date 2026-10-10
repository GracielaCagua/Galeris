# Model Forge

Demo web para la Persona 4: carga de modelos GLB/glTF, biblioteca de recursos, colocación en escena, selección solo en **Modo crear**, transformación con gizmos, eliminación y bloqueo completo en **Modo visualizar**.

## Ejecutar

Como usa módulos ES y carga Three.js desde CDN, hay que servir la carpeta con un servidor local (no abrir `index.html` directamente):

```powershell
python -m http.server 8080
```

Después abrir `http://localhost:8080`.

## Integración con Persona 1

El botón **Guardar JSON** descarga `model-forge-scene.json` con este contrato:

```json
{
  "version": 1,
  "format": "model-forge-scene",
  "objects": [
    {
      "instanceId": "instance-...",
      "modelId": "model-001",
      "position": { "x": 0, "y": 0.7, "z": 0 },
      "rotation": { "x": 0, "y": 0, "z": 0 },
      "scale": { "x": 1, "y": 1, "z": 1 }
    }
  ]
}
```

Los `.blend` deben mantenerse como archivos fuente del repositorio cuando corresponda. Esta demo usa el `.glb`/`.gltf` exportado como formato runtime, que es también el formato recomendado para cargar los recursos en Godot.
