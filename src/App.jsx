import { useCallback, useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { TransformControls } from "three/addons/controls/TransformControls.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

const initialResources = [
  { id: "model-001", name: "Cubo de prueba", source: "Primitiva · GLB compatible", type: "cube" },
  { id: "model-002", name: "Esfera de prueba", source: "Primitiva · GLB compatible", type: "sphere" }
];

const modeLabels = {
  create: ["Modo crear activo", "Listo para crear"],
  edit: ["Modo editar activo", "Arrastra los gizmos para transformar"],
  view: ["Modo visualizar · escena bloqueada", "Solo lectura"]
};

function createPrimitive(type) {
  const group = new THREE.Group();
  const material = new THREE.MeshStandardMaterial({ color: type === "cube" ? 0xb9f36d : 0x72a8ff, roughness: 0.65 });
  const geometry = type === "cube"
    ? new THREE.BoxGeometry(1.25, 1.25, 1.25)
    : new THREE.SphereGeometry(0.78, 32, 20);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  group.add(mesh);
  return group;
}

const round = (value) => Number(value.toFixed(4));
const bytes = (value) => `${(value / 1024 / 1024).toFixed(2)} MB`;

export default function App() {
  const viewportRef = useRef(null);
  const sceneRef = useRef(null);
  const transformRef = useRef(null);
  const objectsRef = useRef([]);
  const selectedRef = useRef(null);
  const loaderRef = useRef(new GLTFLoader());
  const pointerRef = useRef(null);
  const idRef = useRef(3);
  const modeRef = useRef("create");
  const selectObjectRef = useRef(null);
  const [resources, setResources] = useState(initialResources);
  const [objects, setObjects] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [transformValues, setTransformValues] = useState(null);
  const [mode, setMode] = useState("create");
  const [gizmoMode, setGizmoMode] = useState("rotate");
  const [uniformScale, setUniformScale] = useState(true);
  const [toast, setToast] = useState("");
  const [dropActive, setDropActive] = useState(false);

  const notify = useCallback((message) => {
    setToast(message);
    window.clearTimeout(notify.timer);
    notify.timer = window.setTimeout(() => setToast(""), 2400);
  }, []);

  const sync = useCallback(() => {
    const object = selectedRef.current;
    setObjects([...objectsRef.current]);
    setTransformValues(object ? {
      position: object.position,
      rotation: {
        x: THREE.MathUtils.radToDeg(object.rotation.x),
        y: THREE.MathUtils.radToDeg(object.rotation.y),
        z: THREE.MathUtils.radToDeg(object.rotation.z)
      },
      scale: object.scale
    } : null);
  }, []);

  const selectObject = useCallback((object) => {
    if (mode === "view") return;
    selectedRef.current = object;
    setSelectedId(object.userData.instanceId);
    transformRef.current.setMode(gizmoMode);
    transformRef.current.attach(object);
    sync();
  }, [gizmoMode, mode, sync]);

  modeRef.current = mode;
  selectObjectRef.current = selectObject;

  const deselect = useCallback(() => {
    selectedRef.current = null;
    setSelectedId(null);
    transformRef.current?.detach();
    setTransformValues(null);
    setObjects([...objectsRef.current]);
  }, []);

  useEffect(() => {
    const viewport = viewportRef.current;
    const scene = new THREE.Scene();
    scene.background = new THREE.Color("#0b0e14");
    const camera = new THREE.PerspectiveCamera(45, 1, 0.1, 1000);
    camera.position.set(7, 5, 8);
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    viewport.appendChild(renderer.domElement);
    const orbit = new OrbitControls(camera, renderer.domElement);
    orbit.enableDamping = true;
    orbit.target.set(0, 1, 0);
    const transform = new TransformControls(camera, renderer.domElement);
    transform.setSpace("world");
    transform.setSize(1.3);
    transform.addEventListener("dragging-changed", (event) => { orbit.enabled = !event.value; });
    transform.addEventListener("objectChange", sync);
    scene.add(transform.getHelper());
    scene.add(new THREE.HemisphereLight(0xd9e5ff, 0x1b2332, 2.4));
    const light = new THREE.DirectionalLight(0xffffff, 3.5);
    light.position.set(4, 9, 5);
    light.castShadow = true;
    scene.add(light);
    scene.add(new THREE.GridHelper(20, 20, 0x35404f, 0x202833));
    sceneRef.current = scene;
    transformRef.current = transform;
    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    const resize = () => {
      const { width, height } = viewport.getBoundingClientRect();
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height, false);
    };
    const pointerDown = (event) => { pointerRef.current = { x: event.clientX, y: event.clientY }; };
    const pointerUp = (event) => {
      if (!pointerRef.current || modeRef.current === "view") return;
      const distance = Math.hypot(event.clientX - pointerRef.current.x, event.clientY - pointerRef.current.y);
      pointerRef.current = null;
      if (distance > 5 || transform.dragging) return;
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.set(((event.clientX - rect.left) / rect.width) * 2 - 1, -((event.clientY - rect.top) / rect.height) * 2 + 1);
      raycaster.setFromCamera(pointer, camera);
      const hits = raycaster.intersectObjects(objectsRef.current, true);
      if (!hits.length) return deselect();
      let object = hits[0].object;
      while (object.parent && !objectsRef.current.includes(object)) object = object.parent;
      if (objectsRef.current.includes(object)) selectObjectRef.current(object);
    };
    viewport.addEventListener("pointerdown", pointerDown);
    viewport.addEventListener("pointerup", pointerUp);
    const onResize = () => resize();
    window.addEventListener("resize", onResize);
    resize();
    let frame;
    const render = () => { frame = requestAnimationFrame(render); orbit.update(); renderer.render(scene, camera); };
    render();
    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener("resize", onResize);
      viewport.removeEventListener("pointerdown", pointerDown);
      viewport.removeEventListener("pointerup", pointerUp);
      renderer.dispose();
      viewport.removeChild(renderer.domElement);
    };
  }, []);

  useEffect(() => {
    const transform = transformRef.current;
    if (!transform) return;
    transform.setMode(gizmoMode);
    if (selectedRef.current && mode !== "view") transform.attach(selectedRef.current);
  }, [gizmoMode, mode]);

  const placeResource = (resource) => {
    if (mode === "view") return notify("Cambia a Crear o Editar para modificar la escena.");
    const object = resource.factory ? resource.factory() : createPrimitive(resource.type);
    object.userData = { modelId: resource.id, modelName: resource.name, instanceId: `instance-${Date.now()}-${objectsRef.current.length + 1}` };
    object.position.set((objectsRef.current.length % 3 - 1) * 1.8, 0.7, Math.floor(objectsRef.current.length / 3) * 1.5);
    sceneRef.current.add(object);
    objectsRef.current.push(object);
    selectObject(object);
    notify(`${resource.name} añadido a la escena`);
  };

  const loadModel = (file) => {
    if (!file || !/(\.glb|\.gltf)$/i.test(file.name)) return notify("Selecciona un archivo .glb o .gltf.");
    const url = URL.createObjectURL(file);
    loaderRef.current.load(url, (gltf) => {
      const id = `model-${String(idRef.current++).padStart(3, "0")}`;
      setResources((current) => [...current, {
        id, name: file.name.replace(/\.(glb|gltf)$/i, ""), source: `${file.name} · ${bytes(file.size)}`,
        factory: () => {
          const clone = gltf.scene.clone(true);
          clone.traverse((child) => { if (child.isMesh) { child.castShadow = true; child.receiveShadow = true; } });
          return clone;
        }
      }]);
      URL.revokeObjectURL(url);
      notify(`${file.name} disponible en la biblioteca`);
    }, undefined, () => { URL.revokeObjectURL(url); notify("No se pudo cargar el modelo."); });
  };

  const removeSelected = () => {
    const object = selectedRef.current;
    if (!object || mode === "view") return;
    sceneRef.current.remove(object);
    objectsRef.current = objectsRef.current.filter((entry) => entry !== object);
    deselect();
    notify(`${object.userData.modelName} eliminado`);
  };

  const setTransformValue = (type, axis, value) => {
    const object = selectedRef.current;
    if (!object || mode === "view" || !Number.isFinite(Number(value))) return;
    const numeric = Number(value);
    if (type === "rotation") object.rotation[axis] = THREE.MathUtils.degToRad(numeric);
    else if (type === "scale" && uniformScale) object.scale.set(numeric, numeric, numeric);
    else object[type][axis] = numeric;
    sync();
  };

  const saveScene = () => {
    const data = {
      version: 1, format: "model-forge-scene",
      objects: objectsRef.current.map((object) => ({
        instanceId: object.userData.instanceId, modelId: object.userData.modelId,
        position: { x: round(object.position.x), y: round(object.position.y), z: round(object.position.z) },
        rotation: { x: round(object.rotation.x), y: round(object.rotation.y), z: round(object.rotation.z) },
        scale: { x: round(object.scale.x), y: round(object.scale.y), z: round(object.scale.z) }
      }))
    };
    const link = document.createElement("a");
    link.href = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: "application/json" }));
    link.download = "model-forge-scene.json";
    link.click();
    URL.revokeObjectURL(link.href);
    notify("Escena exportada para Persona 1");
  };

  const clearScene = () => {
    objectsRef.current.forEach((object) => sceneRef.current.remove(object));
    objectsRef.current = [];
    deselect();
    notify("Escena limpiada");
  };

  const transformFields = ["position", "rotation", "scale"];
  const axes = ["x", "y", "z"];
  const selectedObject = selectedRef.current;

  return (
    <>
      <header className="topbar">
        <div className="brand"><div className="brand-mark">◆</div><div><strong>MODEL FORGE</strong><span>Editor de escenas 3D · React + Vite</span></div></div>
        <div className="mode-switch">{Object.keys(modeLabels).map((key) => <button key={key} className={`mode-button ${mode === key ? "active" : ""}`} onClick={() => { setMode(key); if (key === "view") deselect(); }}>{key === "create" ? "✦ Crear" : key === "edit" ? "✎ Editar" : "◉ Visualizar"}</button>)}</div>
        <div className="top-actions"><button className="button secondary" onClick={saveScene}>Guardar JSON</button><button className="button danger" onClick={clearScene}>Limpiar escena</button></div>
      </header>
      <main className="workspace">
        <aside className="sidebar">
          <section className="panel-section">
            <div className="section-heading"><div><p className="eyebrow">RECURSOS</p><h2>Biblioteca 3D</h2></div><span className="count-badge">{resources.length}</span></div>
            <label className="upload-zone" htmlFor="model-input"><span className="upload-icon">＋</span><strong>Importar modelo</strong><small>GLB / glTF · arrastra o selecciona</small></label>
            <input id="model-input" type="file" accept=".glb,.gltf,.bin,model/gltf-binary,model/gltf+json" hidden onChange={(event) => loadModel(event.target.files[0])} />
            <div className="resource-list">{resources.map((resource) => <div className="resource-card" key={resource.id} onClick={() => placeResource(resource)}><div className="resource-icon">◇</div><div className="resource-info"><strong>{resource.name}</strong><small>{resource.source}</small></div><span className="add-icon">+</span></div>)}</div>
          </section>
          <section className="panel-section">
            <div className="section-heading"><div><p className="eyebrow">ESCENA ACTUAL</p><h2>Objetos colocados</h2></div><span className="count-badge">{objects.length}</span></div>
            <div className={objects.length ? "scene-list" : "scene-list empty-state"}>{objects.length ? objects.map((object) => <div className={`scene-item ${object.userData.instanceId === selectedId ? "selected" : ""}`} key={object.userData.instanceId} onClick={() => selectObject(object)}><div className="resource-icon">◇</div><div className="scene-info"><strong>{object.userData.modelName}</strong><small>{object.userData.instanceId}</small></div></div>) : "Aún no hay objetos en la escena."}</div>
          </section>
          <section className="panel-section tips"><p className="eyebrow">CONTROLES</p><p><kbd>Supr</kbd> elimina el objeto seleccionado</p><p>En <strong>Crear</strong> y <strong>Editar</strong> arrastra los controles.</p><p>En <strong>Visualizar</strong> la escena queda bloqueada.</p></section>
        </aside>
        <section className="viewport-shell" onDragOver={(event) => { event.preventDefault(); setDropActive(true); }} onDragLeave={() => setDropActive(false)} onDrop={(event) => { event.preventDefault(); setDropActive(false); loadModel(event.dataTransfer.files[0]); }}>
          <div className="viewport-toolbar"><div className="toolbar-status"><span className="status-dot"></span>{modeLabels[mode][0]}</div><div className="gizmo-tools">{[["translate", "↕ Mover"], ["rotate", "↻ Rotar"], ["scale", "⤢ Escalar"]].map(([key, label]) => <button key={key} className={`gizmo-tool ${gizmoMode === key ? "active" : ""}`} onClick={() => setGizmoMode(key)}>{label}</button>)}</div><div className="toolbar-help">Haz clic en un objeto y arrastra sus controles</div><span className="selection-label">{selectedObject?.userData.modelName || "Sin selección"}</span></div>
          <div ref={viewportRef} className="viewport"></div>
          {dropActive && <div className="drop-hint visible">Suelta un archivo GLB/glTF para importarlo</div>}
          <div className="viewport-footer"><span>Y arriba · unidades en metros</span><span>{modeLabels[mode][1]}</span></div>
        </section>
        <aside className="inspector">
          <div className="inspector-header"><p className="eyebrow">INSPECTOR</p><h2>{selectedObject?.userData.modelName || "Sin selección"}</h2><p>{selectedObject ? (mode === "view" ? "La escena está bloqueada en Modo visualizar." : "Usa los controles sobre el objeto para transformarlo.") : "Selecciona un objeto en Modo crear o Editar."}</p></div>
          <div className={`transform-fields ${!selectedObject || mode === "view" ? "is-disabled" : ""}`}>
            {transformFields.map((type) => <div className="field-group" key={type}><div className="field-heading"><span>{type === "position" ? "Posición" : type === "rotation" ? "Rotación" : "Escala"}</span><span className="axis-label">{type === "rotation" ? "GRADOS" : "XYZ"}</span></div><div className="vector-fields">{axes.map((axis) => <label key={axis}><i className={axis}>{axis.toUpperCase()}</i><input disabled={!selectedObject || mode === "view"} type="number" step={type === "rotation" ? "1" : "0.1"} value={transformValues ? Number(transformValues[type][axis]).toFixed(2) : ""} onChange={(event) => setTransformValue(type, axis, event.target.value)} /></label>)}</div></div>)}
          </div>
          <div className="inspector-footer"><div className="model-meta"><span>IDENTIFICADOR</span><code>{selectedObject?.userData.modelId || "—"}</code></div><button className="button danger full" disabled={!selectedObject || mode === "view"} onClick={removeSelected}>Eliminar objeto</button><button className="link-button scale-link" disabled={!selectedObject || mode === "view"} onClick={() => setUniformScale(!uniformScale)}>{uniformScale ? "Escala vinculada" : "Escala libre"}</button></div>
        </aside>
      </main>
      {toast && <div className="toast visible">{toast}</div>}
    </>
  );
}
