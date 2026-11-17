import { useCallback, useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { TransformControls } from "three/addons/controls/TransformControls.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { api, initials, roleLabel } from "./api.js";

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

const snapToBlock = (value) => Math.round(value);

function createCanvasGrid(width, depth) {
  const group = new THREE.Group();
  const material = new THREE.LineBasicMaterial({ color: 0x35404f });
  const points = [];
  const halfWidth = width / 2;
  const halfDepth = depth / 2;

  for (let x = -halfWidth; x <= halfWidth; x += 1) {
    points.push(new THREE.Vector3(x, 0.006, -halfDepth));
    points.push(new THREE.Vector3(x, 0.006, halfDepth));
  }
  for (let z = -halfDepth; z <= halfDepth; z += 1) {
    points.push(new THREE.Vector3(-halfWidth, 0.006, z));
    points.push(new THREE.Vector3(halfWidth, 0.006, z));
  }

  const geometry = new THREE.BufferGeometry().setFromPoints(points);
  group.add(new THREE.LineSegments(geometry, material));
  return group;
}

function createWall(width = 4, height = 3) {
  const group = new THREE.Group();
  const material = new THREE.MeshStandardMaterial({ color: 0xe7e9ed, roughness: 0.8 });
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, 0.2), material);
  mesh.position.y = height / 2;
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  group.add(mesh);
  group.userData.wall = true;
  group.userData.width = width;
  group.userData.height = height;
  group.userData.thickness = 0.2;
  group.userData.hasCollision = true;
  group.userData.collision = { type: "box", width, height, thickness: 0.2 };
  return group;
}

const round = (value) => Number(value.toFixed(4));
const bytes = (value) => `${(value / 1024 / 1024).toFixed(2)} MB`;

export default function Editor({ session, onLogout, onOpenAdmin, initialProject = null }) {
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
  const [projects, setProjects] = useState([]);
  const [projectId, setProjectId] = useState(null);
  const [projectName, setProjectName] = useState("Mi galería");
  const [projectsLoading, setProjectsLoading] = useState(true);
  const [canvasSize, setCanvasSize] = useState({ x: 3, z: 5 });

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
    transform.addEventListener("objectChange", () => {
      keepObjectOnFloor(selectedRef.current);
      sync();
    });
    scene.add(transform.getHelper());
    scene.add(new THREE.HemisphereLight(0xd9e5ff, 0x1b2332, 2.4));
    const light = new THREE.DirectionalLight(0xffffff, 3.5);
    light.position.set(4, 9, 5);
    light.castShadow = true;
    scene.add(light);
    const grid = createCanvasGrid(3, 5);
    scene.add(grid);
    scene.userData.canvasGrid = grid;
    const floor = new THREE.Mesh(
      new THREE.BoxGeometry(3, 0.1, 5),
      new THREE.MeshStandardMaterial({ color: 0x68717d, roughness: 0.9 })
    );
    floor.position.y = -0.05;
    floor.userData = {
      modelName: "Suelo del lienzo",
      hasCollision: true,
      canvasFloor: true,
      collision: { type: "box", width: 3, height: 0.1, depth: 5, top: 0 }
    };
    floor.receiveShadow = true;
    scene.add(floor);
    scene.userData.canvasFloor = floor;
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

  const rebuildCanvas = (nextSize) => {
    const floor = sceneRef.current?.userData.canvasFloor;
    const grid = sceneRef.current?.userData.canvasGrid;
    if (!floor || !grid) return;
    floor.geometry.dispose();
    floor.geometry = new THREE.BoxGeometry(nextSize.x, 0.1, nextSize.z);
    floor.userData.collision.width = nextSize.x;
    floor.userData.collision.depth = nextSize.z;
    const nextGrid = createCanvasGrid(nextSize.x, nextSize.z);
    sceneRef.current.remove(grid);
    grid.traverse((child) => {
      if (child.geometry) child.geometry.dispose();
      if (child.material) child.material.dispose();
    });
    sceneRef.current.add(nextGrid);
    sceneRef.current.userData.canvasGrid = nextGrid;
    setCanvasSize(nextSize);
  };

  const snapWall = (wall) => {
    if (!wall?.userData.wall) return;
    wall.scale.set(1, 1, 1);
    wall.position.y = 0;
    wall.position.x = snapToBlock(wall.position.x);
    wall.position.z = snapToBlock(wall.position.z);
    wall.rotation.y = THREE.MathUtils.degToRad(
      Math.round(THREE.MathUtils.radToDeg(wall.rotation.y) / 90) * 90
    );
    wall.userData.width = Math.max(1, snapToBlock(wall.userData.width));
    wall.userData.height = Math.max(1, snapToBlock(wall.userData.height));
    wall.userData.collision.width = wall.userData.width;
    wall.userData.collision.height = wall.userData.height;
  };

  const keepObjectOnFloor = (object) => {
    if (!object || object.userData.canvasFloor) return;
    if (object.userData.wall) {
      snapWall(object);
      return;
    }
    object.updateMatrixWorld(true);
    const bounds = new THREE.Box3().setFromObject(object);
    if (bounds.min.y < 0) object.position.y += -bounds.min.y;
  };

  const addWall = () => {
    if (mode === "view") return notify("Cambia a Crear o Editar para crear paredes.");
    const wall = createWall();
    wall.userData = {
      ...wall.userData,
      modelId: "wall",
      modelName: "Pared",
      instanceId: `wall-${Date.now()}`,
      collision: { type: "box", width: 4, height: 3, thickness: 0.2 }
    };
    wall.position.set(0, 0, 0);
    sceneRef.current.add(wall);
    objectsRef.current.push(wall);
    selectObject(wall);
    notify("Pared creada con colisión");
  };

  const rotateSelected = (degrees) => {
    if (!selectedRef.current || mode === "view") return;
    selectedRef.current.rotation.y += THREE.MathUtils.degToRad(degrees);
    selectedRef.current.rotation.y = THREE.MathUtils.degToRad(
      Math.round(THREE.MathUtils.radToDeg(selectedRef.current.rotation.y) / 90) * 90
    );
    snapWall(selectedRef.current);
    sync();
  };

  const updateWallDimensions = (field, value) => {
    const wall = selectedRef.current;
    if (!wall?.userData.wall || mode === "view") return;
    const next = Math.max(1, snapToBlock(Number(value) || 1));
    wall.userData[field] = next;
    wall.userData.collision[field] = next;
    const mesh = wall.children[0];
    mesh.geometry.dispose();
    mesh.geometry = new THREE.BoxGeometry(wall.userData.width, wall.userData.height, 0.2);
    mesh.position.y = wall.userData.height / 2;
    sync();
  };

  useEffect(() => {
    const transform = transformRef.current;
    if (!transform) return;
    transform.setMode(gizmoMode);
    if (selectedRef.current && mode !== "view") transform.attach(selectedRef.current);
  }, [gizmoMode, mode]);

  const placeResource = (resource) => {
    if (mode === "view") return notify("Cambia a Crear o Editar para modificar la escena.");
    const object = resource.factory ? resource.factory() : createPrimitive(resource.type);
    object.userData = { modelId: resource.id, resourceId: resource.id, modelName: resource.name, instanceId: `instance-${Date.now()}-${objectsRef.current.length + 1}` };
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
      const localResource = {
        id, name: file.name.replace(/\.(glb|gltf)$/i, ""), source: `${file.name} · ${bytes(file.size)}`,
        factory: () => {
          const clone = gltf.scene.clone(true);
          clone.traverse((child) => { if (child.isMesh) { child.castShadow = true; child.receiveShadow = true; } });
          return clone;
        }
      };
      setResources((current) => [...current, localResource]);
      api.uploadResource(session.access_token, file)
        .then((resource) => {
          setResources((current) => current.map((entry) => entry.id === id
            ? { ...entry, id: resource.id, source: `${file.name} · ${bytes(file.size)}`, fileUrl: api.resourceFileUrl(resource) }
            : entry));
          objectsRef.current.forEach((object) => {
            if (object.userData.resourceId === id) object.userData.resourceId = resource.id;
          });
          gltf.scene.userData.resourceId = resource.id;
          notify(`${file.name} guardado en tu biblioteca y disponible en proyectos`);
        })
        .catch((error) => notify(error.message || "El modelo quedó solo en esta sesión."));
      URL.revokeObjectURL(url);
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
    if (object.userData.wall && axis === "y" && type === "position") return;
    if (type === "rotation") object.rotation[axis] = THREE.MathUtils.degToRad(numeric);
    else if (type === "scale" && uniformScale) object.scale.set(numeric, numeric, numeric);
    else object[type][axis] = numeric;
    keepObjectOnFloor(object);
    sync();
  };

  const saveScene = () => {
    const data = {
      version: 1, format: "model-forge-scene",
      canvas: { blocksX: canvasSize.x, blocksZ: canvasSize.z, blockSize: 1 },
      objects: objectsRef.current.map((object) => ({
        instanceId: object.userData.instanceId, modelId: object.userData.modelId,
        type: object.userData.wall ? "wall" : "object",
        width: object.userData.width, height: object.userData.height,
        hasCollision: Boolean(object.userData.hasCollision),
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

  const getSceneData = () => ({
    version: 1,
    format: "model-forge-scene",
    canvas: { blocksX: canvasSize.x, blocksZ: canvasSize.z, blockSize: 1 },
    objects: objectsRef.current.map((object) => ({
      instanceId: object.userData.instanceId,
      modelId: object.userData.modelId,
      modelName: object.userData.modelName,
      resourceId: object.userData.resourceId || null,
      type: object.userData.wall ? "wall" : "object",
      width: object.userData.width, height: object.userData.height,
      hasCollision: Boolean(object.userData.hasCollision),
      position: { x: round(object.position.x), y: round(object.position.y), z: round(object.position.z) },
      rotation: { x: round(object.rotation.x), y: round(object.rotation.y), z: round(object.rotation.z) },
      scale: { x: round(object.scale.x), y: round(object.scale.y), z: round(object.scale.z) }
    }))
  });

  const saveProject = async () => {
    const name = projectName.trim();
    if (!name) return notify("Escribe un nombre para tu proyecto.");
    try {
      const payload = { name, description: "Galería creada desde el editor", data: getSceneData() };
      const saved = projectId
        ? await api.updateProject(session.access_token, projectId, payload)
        : await api.createProject(session.access_token, payload);
      setProjectId(saved.id);
      setProjects((current) => [saved, ...current.filter((project) => project.id !== saved.id)]);
      notify("Proyecto guardado en tu cuenta");
    } catch (error) {
      notify(error.message || "No se pudo guardar el proyecto.");
    }
  };

  const clearSceneSilently = () => {
    objectsRef.current.forEach((object) => sceneRef.current.remove(object));
    objectsRef.current = [];
    deselect();
  };

  const loadProjectScene = async (project) => {
    clearSceneSilently();
    const data = project.data || {};
    if (data.canvas) rebuildCanvas({
      x: Math.max(1, Number(data.canvas.blocksX) || 3),
      z: Math.max(1, Number(data.canvas.blocksZ) || 5)
    });
    const storedResources = await api.listResources(session.access_token);
    const resourcesById = new Map([...resources, ...storedResources.map((resource) => ({
      ...resource,
      fileUrl: api.resourceFileUrl(resource),
      source: `${resource.type} · ${resource.category}`
    }))].map((resource) => [String(resource.id), resource]));
    for (const saved of data.objects || []) {
      let object;
      if (saved.type === "wall") {
        object = createWall(saved.width || 4, saved.height || 3);
        object.userData = { ...saved, wall: true, modelName: saved.modelName || "Pared", hasCollision: true };
      } else {
        const resource = resourcesById.get(String(saved.resourceId || saved.modelId));
        if (!resource) continue;
        if (resource.factory) {
          object = resource.factory();
        } else if (resource.fileUrl) {
          object = await new Promise((resolve, reject) => loaderRef.current.load(resource.fileUrl, (gltf) => resolve(gltf.scene), undefined, reject));
        }
        if (!object) continue;
        object.userData = { ...saved, modelId: resource.id, modelName: resource.name };
      }
      object.position.set(saved.position?.x || 0, saved.position?.y || 0, saved.position?.z || 0);
      object.rotation.set(saved.rotation?.x || 0, saved.rotation?.y || 0, saved.rotation?.z || 0);
      object.scale.set(saved.scale?.x || 1, saved.scale?.y || 1, saved.scale?.z || 1);
      keepObjectOnFloor(object);
      sceneRef.current.add(object);
      objectsRef.current.push(object);
    }
    sync();
  };

  useEffect(() => {
    if (initialProject && sceneRef.current) {
      setProjectId(initialProject.id);
      setProjectName(initialProject.name);
      loadProjectScene(initialProject).catch((error) => notify(error.message || "No se pudo cargar el proyecto."));
    }
  }, [initialProject]);

  useEffect(() => {
    let cancelled = false;
    Promise.all([api.listProjects(session.access_token), api.listResources?.(session.access_token) || Promise.resolve([])])
      .then(([items, storedResources]) => { if (!cancelled) { setProjects(items); setResources((current) => [...current, ...storedResources.map((resource) => ({ ...resource, fileUrl: api.resourceFileUrl(resource), source: `${resource.type} · ${resource.category}` }))]); } })
      .catch((error) => { if (!cancelled) notify(error.message || "No se pudieron cargar tus proyectos."); })
      .finally(() => { if (!cancelled) setProjectsLoading(false); });
    return () => { cancelled = true; };
  }, [session.access_token, notify]);

  const openProject = async (id) => {
    try {
      const project = await api.getProject(session.access_token, id);
      setProjectId(project.id);
      setProjectName(project.name);
      await loadProjectScene(project);
      notify(`Proyecto "${project.name}" seleccionado`);
    } catch (error) {
      notify(error.message || "No se pudo abrir el proyecto.");
    }
  };

  const createProject = () => {
    clearSceneSilently();
    setProjectId(null);
    setProjectName("Nuevo proyecto");
    setCanvasSize({ x: 3, z: 5 });
    rebuildCanvas({ x: 3, z: 5 });
    notify("Nuevo proyecto listo");
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
        <div className="top-actions">
          {session?.user?.role === "admin" && <button className="button secondary" onClick={onOpenAdmin}>Usuarios</button>}
          <button className="button secondary" onClick={saveProject}>Guardar proyecto</button>
          <button className="button secondary" onClick={saveScene}>Exportar JSON</button>
          <button className="button danger" onClick={clearScene}>Limpiar</button>
          <div className="editor-user" title={`${session?.user?.full_name || session?.user?.username || "Invitado"} · ${roleLabel(session?.user?.role)}`}>
            <span className="editor-avatar">{initials(session?.user?.full_name || session?.user?.username || "Invitado")}</span>
            <span className="editor-user-name">{session?.user?.full_name || session?.user?.username || "Invitado"}</span>
            <button type="button" className="editor-logout" onClick={() => onLogout()} aria-label="Cerrar sesión" title="Cerrar sesión">⏻</button>
          </div>
        </div>
      </header>
      <main className="workspace">
        <aside className="sidebar">
          <section className="panel-section">
            <div className="section-heading"><div><p className="eyebrow">MI CUENTA</p><h2>Mis proyectos</h2></div><div className="project-heading-actions"><span className="count-badge">{projects.length}</span><button type="button" className="link-button" onClick={createProject}>＋ Nuevo</button></div></div>
            <label className="form-field project-name-field"><span>Proyecto actual</span><input value={projectName} onChange={(event) => setProjectName(event.target.value)} maxLength={255} /></label>
            <div className="project-list">
              {projectsLoading && <small>Cargando proyectos…</small>}
              {!projectsLoading && !projects.length && <small>Aún no tienes proyectos guardados.</small>}
              {projects.map((project) => (
                <button type="button" className={`project-item ${project.id === projectId ? "selected" : ""}`} key={project.id} onClick={() => openProject(project.id)}>
                  <strong>{project.name}</strong><small>{new Date(project.updated_at).toLocaleDateString("es-ES")}</small>
                </button>
              ))}
            </div>
          </section>
          <section className="panel-section">
            <div className="section-heading"><div><p className="eyebrow">CONSTRUCCIÓN</p><h2>Sala y paredes</h2></div></div>
            <div className="canvas-size-fields">
              <label>Bloques X<input type="number" min="1" max="30" step="1" value={canvasSize.x} disabled={mode === "view"} onChange={(event) => rebuildCanvas({ ...canvasSize, x: Math.max(1, Math.round(Number(event.target.value) || 1)) })} /></label>
              <label>Bloques Z<input type="number" min="1" max="30" step="1" value={canvasSize.z} disabled={mode === "view"} onChange={(event) => rebuildCanvas({ ...canvasSize, z: Math.max(1, Math.round(Number(event.target.value) || 1)) })} /></label>
            </div>
            <small className="panel-help">Cada bloque mide 1 metro. Suelo con colisión.</small>
            <div className="construction-actions">
              <button className="button primary" disabled={mode === "view"} onClick={addWall}>＋ Crear pared</button>
              <button className="button" disabled={!selectedObject?.userData.wall || mode === "view"} onClick={() => rotateSelected(90)}>Girar 90°</button>
              <button className="button" disabled={!selectedObject?.userData.wall || mode === "view"} onClick={() => rotateSelected(180)}>Girar 180°</button>
            </div>
          </section>
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
            {selectedObject?.userData.wall && <div className="field-group"><div className="field-heading"><span>Dimensiones de pared</span><span className="axis-label">METROS</span></div><div className="vector-fields"><label><i className="x">ANCHO</i><input disabled={mode === "view"} type="number" min="0.1" step="0.1" value={selectedObject.userData.width} onChange={(event) => updateWallDimensions("width", event.target.value)} /></label><label><i className="y">ALTO</i><input disabled={mode === "view"} type="number" min="0.1" step="0.1" value={selectedObject.userData.height} onChange={(event) => updateWallDimensions("height", event.target.value)} /></label></div><small className="panel-help">Colisión tipo caja activa.</small></div>}
            {transformFields.map((type) => <div className="field-group" key={type}><div className="field-heading"><span>{type === "position" ? "Posición" : type === "rotation" ? "Rotación" : "Escala"}</span><span className="axis-label">{type === "rotation" ? "GRADOS" : "XYZ"}</span></div><div className="vector-fields">{axes.map((axis) => <label key={axis}><i className={axis}>{axis.toUpperCase()}</i><input disabled={!selectedObject || mode === "view"} type="number" step={type === "rotation" ? "1" : "0.1"} value={transformValues ? Number(transformValues[type][axis]).toFixed(2) : ""} onChange={(event) => setTransformValue(type, axis, event.target.value)} /></label>)}</div></div>)}
          </div>
          <div className="inspector-footer"><div className="model-meta"><span>IDENTIFICADOR</span><code>{selectedObject?.userData.modelId || "—"}</code></div><button className="button danger full" disabled={!selectedObject || mode === "view"} onClick={removeSelected}>Eliminar objeto</button><button className="link-button scale-link" disabled={!selectedObject || mode === "view"} onClick={() => setUniformScale(!uniformScale)}>{uniformScale ? "Escala vinculada" : "Escala libre"}</button></div>
        </aside>
      </main>
      {toast && <div className="toast visible">{toast}</div>}
    </>
  );
}
