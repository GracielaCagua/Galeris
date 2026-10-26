import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { TransformControls } from "three/addons/controls/TransformControls.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

const $ = (selector) => document.querySelector(selector);
const viewport = $("#viewport");
const resources = [];
const sceneObjects = [];
let selectedObject = null;
let currentMode = "create";
let uniformScale = true;
let resourceSequence = 1;
let gizmoMode = "rotate";
let pointerDownPosition = null;

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
transform.setMode(gizmoMode);
transform.setSpace("world");
transform.setSize(1.3);
transform.showX = true;
transform.showY = true;
transform.showZ = true;
transform.addEventListener("dragging-changed", (event) => { orbit.enabled = !event.value; });
transform.addEventListener("objectChange", () => { updateInspector(); updateSceneList(); });
const transformHelper = transform.getHelper();
scene.add(transformHelper);

// Show only the positive axis arrows; the invisible negative pickers remain usable.
function hideNegativeTranslateArrows() {
  const translateGizmo = transform.getHelper().getObjectByName("gizmo");
  if (!translateGizmo) return;
  translateGizmo.traverse((child) => {
    if (!child.isMesh) return;
    const { x, y, z } = child.position;
    if (x < -0.01 || y < -0.01 || z < -0.01) child.visible = false;
  });
}
hideNegativeTranslateArrows();

scene.add(new THREE.HemisphereLight(0xd9e5ff, 0x1b2332, 2.4));
const keyLight = new THREE.DirectionalLight(0xffffff, 3.5);
keyLight.position.set(4, 9, 5);
keyLight.castShadow = true;
scene.add(keyLight);
const grid = new THREE.GridHelper(20, 20, 0x35404f, 0x202833);
scene.add(grid);

const loader = new GLTFLoader();
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const clock = new THREE.Clock();

function resize() {
  const { width, height } = viewport.getBoundingClientRect();
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
  renderer.setSize(width, height, false);
}
window.addEventListener("resize", resize);
resize();

function makePreview(type) {
  const preview = new THREE.Group();
  const material = new THREE.MeshStandardMaterial({ color: type === "cube" ? 0xb9f36d : 0x72a8ff, roughness: .65, metalness: .1 });
  const mesh = type === "cube"
    ? new THREE.Mesh(new THREE.BoxGeometry(1.25, 1.25, 1.25), material)
    : new THREE.Mesh(new THREE.SphereGeometry(.78, 32, 20), material);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  preview.add(mesh);
  return preview;
}

function addResource(name, source, objectFactory) {
  const resource = { id: `model-${String(resourceSequence++).padStart(3, "0")}`, name, source, objectFactory };
  resources.push(resource);
  renderResources();
  return resource;
}

addResource("Cubo de prueba", "Primitiva · GLB compatible", () => makePreview("cube"));
addResource("Esfera de prueba", "Primitiva · GLB compatible", () => makePreview("sphere"));

function renderResources() {
  $("#resource-count").textContent = resources.length;
  $("#resource-list").innerHTML = resources.map((resource) => `
    <div class="resource-card" data-resource-id="${resource.id}" title="Añadir a la escena">
      <div class="resource-icon">◇</div>
      <div class="resource-info"><strong>${escapeHtml(resource.name)}</strong><small>${escapeHtml(resource.source)}</small></div>
      <span class="add-icon">+</span>
    </div>
  `).join("");
  document.querySelectorAll(".resource-card").forEach((card) => card.addEventListener("click", () => placeResource(card.dataset.resourceId)));
}

function placeResource(resourceId) {
  if (currentMode === "view") return showToast("Cambia a Crear o Editar para modificar la escena.");
  const resource = resources.find((item) => item.id === resourceId);
  if (!resource) return;
  const object = resource.objectFactory();
  object.userData = { modelId: resource.id, modelName: resource.name, instanceId: `instance-${Date.now()}-${sceneObjects.length + 1}` };
  object.position.set((sceneObjects.length % 3 - 1) * 1.8, .7, Math.floor(sceneObjects.length / 3) * 1.5);
  scene.add(object);
  sceneObjects.push(object);
  selectObject(object);
  updateSceneList();
  showToast(`${resource.name} añadido a la escena`);
}

function selectObject(object) {
  if (currentMode === "view") return;
  selectedObject = object;
  transform.setMode(gizmoMode);
  transform.attach(object);
  $("#selection-label").textContent = object.userData.modelName;
  updateInspector();
  updateSceneList();
}

function deselect() {
  selectedObject = null;
  transform.detach();
  $("#selection-label").textContent = "Sin selección";
  updateInspector();
  updateSceneList();
}

function updateInspector() {
  const disabled = !selectedObject || currentMode === "view";
  $("#transform-fields").classList.toggle("is-disabled", disabled);
  document.querySelectorAll("[data-transform]").forEach((input) => { input.disabled = disabled; });
  $("#delete-button").disabled = disabled;
  $("#inspector-title").textContent = selectedObject ? selectedObject.userData.modelName : "Sin selección";
  $("#inspector-subtitle").textContent = selectedObject ? (currentMode === "view" ? "La escena está bloqueada en Modo visualizar." : "Usa los aros para rotar; pulsa W para mover y R para escalar.") : "Selecciona un objeto en Modo crear o Editar.";
  $("#model-id").textContent = selectedObject?.userData.modelId || "—";
  if (!selectedObject) return;
  const values = {
    position: selectedObject.position,
    rotation: { x: THREE.MathUtils.radToDeg(selectedObject.rotation.x), y: THREE.MathUtils.radToDeg(selectedObject.rotation.y), z: THREE.MathUtils.radToDeg(selectedObject.rotation.z) },
    scale: selectedObject.scale
  };
  document.querySelectorAll("[data-transform]").forEach((input) => {
    input.value = Number(values[input.dataset.transform][input.dataset.axis]).toFixed(2);
  });
}

function updateSceneList() {
  $("#object-count").textContent = sceneObjects.length;
  const list = $("#scene-list");
  if (!sceneObjects.length) { list.className = "scene-list empty-state"; list.textContent = "Aún no hay objetos en la escena."; return; }
  list.className = "scene-list";
  list.innerHTML = sceneObjects.map((object) => `
    <div class="scene-item ${object === selectedObject ? "selected" : ""}" data-instance-id="${object.userData.instanceId}">
      <div class="resource-icon">◇</div>
      <div class="scene-info"><strong>${escapeHtml(object.userData.modelName)}</strong><small>${object.userData.instanceId}</small></div>
    </div>
  `).join("");
  document.querySelectorAll(".scene-item").forEach((item) => item.addEventListener("click", () => {
    const object = sceneObjects.find((entry) => entry.userData.instanceId === item.dataset.instanceId);
    if (object) selectObject(object);
  }));
}

function removeSelected() {
  if (!selectedObject || currentMode === "view") return;
  const name = selectedObject.userData.modelName;
  scene.remove(selectedObject);
  sceneObjects.splice(sceneObjects.indexOf(selectedObject), 1);
  deselect();
  showToast(`${name} eliminado`);
}

function setMode(mode) {
  currentMode = mode;
  document.querySelectorAll(".mode-button").forEach((button) => button.classList.toggle("active", button.dataset.mode === mode));
  const labels = {
    create: ["Modo crear activo", "Listo para crear"],
    edit: ["Modo editar activo", "Arrastra los gizmos para transformar"],
    view: ["Modo visualizar · escena bloqueada", "Solo lectura"]
  };
  $("#mode-label").textContent = labels[mode][0];
  $("#load-status").textContent = labels[mode][1];
  if (mode === "view") deselect();
  else if (selectedObject) {
    transform.setMode(gizmoMode);
    transform.attach(selectedObject);
  }
  updateInspector();
}

function setGizmoMode(mode) {
  gizmoMode = mode;
  transform.setMode(mode);
  document.querySelectorAll(".gizmo-tool").forEach((button) => {
    button.classList.toggle("active", button.dataset.gizmoMode === mode);
  });
  const messages = {
    translate: "Arrastra las flechas X, Y o Z para mover",
    rotate: "Arrastra los aros X, Y o Z para rotar",
    scale: "Arrastra los controles X, Y o Z para escalar"
  };
  $("#load-status").textContent = selectedObject && currentMode !== "view" ? messages[mode] : "Selecciona un objeto para editar";
  updateInspector();
}

function saveScene() {
  const payload = {
    version: 1,
    format: "model-forge-scene",
    objects: sceneObjects.map((object) => ({
      instanceId: object.userData.instanceId,
      modelId: object.userData.modelId,
      position: { x: round(object.position.x), y: round(object.position.y), z: round(object.position.z) },
      rotation: { x: round(object.rotation.x), y: round(object.rotation.y), z: round(object.rotation.z) },
      scale: { x: round(object.scale.x), y: round(object.scale.y), z: round(object.scale.z) }
    }))
  };
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = "model-forge-scene.json";
  link.click();
  URL.revokeObjectURL(link.href);
  showToast("Escena exportada para Persona 1");
}

function handleModelFile(file) {
  if (!file || !/(\.glb|\.gltf)$/i.test(file.name)) return showToast("Selecciona un archivo .glb o .gltf.");
  const url = URL.createObjectURL(file);
  loader.load(url, (gltf) => {
    addResource(file.name.replace(/\.(glb|gltf)$/i, ""), `${file.name} · ${formatBytes(file.size)}`, () => {
      const clone = gltf.scene.clone(true);
      clone.traverse((child) => { if (child.isMesh) { child.castShadow = true; child.receiveShadow = true; } });
      return clone;
    });
    URL.revokeObjectURL(url);
    showToast(`${file.name} disponible en la biblioteca`);
  }, undefined, () => { URL.revokeObjectURL(url); showToast("No se pudo cargar el modelo."); });
}

document.querySelectorAll(".mode-button").forEach((button) => button.addEventListener("click", () => setMode(button.dataset.mode)));
document.querySelectorAll(".gizmo-tool").forEach((button) => button.addEventListener("click", () => setGizmoMode(button.dataset.gizmoMode)));
$("#model-input").addEventListener("change", (event) => handleModelFile(event.target.files[0]));
$("#delete-button").addEventListener("click", removeSelected);
$("#save-button").addEventListener("click", saveScene);
$("#clear-button").addEventListener("click", () => {
  if (!sceneObjects.length) return;
  sceneObjects.forEach((object) => scene.remove(object));
  sceneObjects.length = 0;
  deselect();
  showToast("Escena limpiada");
});
$("#uniform-scale").addEventListener("click", () => {
  uniformScale = !uniformScale;
  $("#uniform-scale").classList.toggle("active", uniformScale);
  $("#uniform-scale").textContent = uniformScale ? "Vinculada" : "Libre";
});
document.querySelectorAll("[data-transform]").forEach((input) => input.addEventListener("change", () => {
  if (!selectedObject || currentMode !== "create") return;
  const type = input.dataset.transform;
  const axis = input.dataset.axis;
  const value = Number(input.value);
  if (!Number.isFinite(value)) return updateInspector();
  if (type === "rotation") selectedObject.rotation[axis] = THREE.MathUtils.degToRad(value);
  else {
    selectedObject[type][axis] = value;
    if (type === "scale" && uniformScale) selectedObject.scale.set(value, value, value);
  }
  updateInspector();
}));
window.addEventListener("keydown", (event) => {
  if (event.key === "Delete") removeSelected();
});
viewport.addEventListener("pointerdown", (event) => {
  if (currentMode === "view" || event.target !== renderer.domElement) return;
  pointerDownPosition = { x: event.clientX, y: event.clientY };
});
viewport.addEventListener("pointerup", (event) => {
  if (currentMode === "view" || event.target !== renderer.domElement || !pointerDownPosition) return;
  const distance = Math.hypot(event.clientX - pointerDownPosition.x, event.clientY - pointerDownPosition.y);
  pointerDownPosition = null;
  if (distance > 5 || transform.dragging) return;
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
  raycaster.setFromCamera(pointer, camera);
  const hits = raycaster.intersectObjects(sceneObjects, true);
  if (!hits.length) return deselect();
  let object = hits[0].object;
  while (object.parent && !sceneObjects.includes(object)) object = object.parent;
  if (sceneObjects.includes(object)) selectObject(object);
});
viewport.addEventListener("dragover", (event) => { event.preventDefault(); $("#drop-hint").classList.add("visible"); });
viewport.addEventListener("dragleave", () => $("#drop-hint").classList.remove("visible"));
viewport.addEventListener("drop", (event) => { event.preventDefault(); $("#drop-hint").classList.remove("visible"); handleModelFile(event.dataTransfer.files[0]); });

function animate() {
  requestAnimationFrame(animate);
  orbit.update();
  renderer.render(scene, camera);
}
animate();
function round(value) { return Number(value.toFixed(4)); }
function formatBytes(bytes) { return `${(bytes / 1024 / 1024).toFixed(2)} MB`; }
function escapeHtml(value) { return value.replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[char])); }
let toastTimer;
function showToast(message) {
  const toast = $("#toast");
  toast.textContent = message;
  toast.classList.add("visible");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("visible"), 2600);
}
