const API_URL = (import.meta.env.VITE_API_URL || "http://127.0.0.1:8000").replace(/\/$/, "");
const SESSION_KEY = "galeris.session.v1";

export class ApiError extends Error {
  constructor(message, status = 0) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

export function loadSession() {
  try {
    const raw = window.localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw);
    return session?.access_token && session?.user ? session : null;
  } catch {
    return null;
  }
}

export function saveSession(session) {
  window.localStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

export function clearStoredSession() {
  window.localStorage.removeItem(SESSION_KEY);
}

export function initials(name = "") {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase() || "?";
}

export function roleLabel(role) {
  return role === "admin" ? "Administrador" : "Usuario";
}

const dateFormatter = new Intl.DateTimeFormat("es-ES", { day: "2-digit", month: "short", year: "numeric" });
const dateTimeFormatter = new Intl.DateTimeFormat("es-ES", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

export function formatDate(value) {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "—" : dateFormatter.format(date);
}

export function formatDateTime(value) {
  if (!value) return "Nunca";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "Nunca" : dateTimeFormatter.format(date);
}

async function request(path, { method = "GET", body, token, headers } = {}) {
  const options = { method, headers: { Accept: "application/json", ...headers } };
  if (body !== undefined) {
    options.headers["Content-Type"] = "application/json";
    options.body = JSON.stringify(body);
  }
  if (token) options.headers.Authorization = `Bearer ${token}`;

  let response;
  try {
    response = await fetch(`${API_URL}${path}`, options);
  } catch {
    throw new ApiError("No se pudo conectar con la API. Comprueba que el backend esté en marcha.", 0);
  }

  if (response.status === 204) return null;

  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }

  if (!response.ok) {
    const detail = data && typeof data === "object" ? data.detail : null;
    const message = Array.isArray(detail)
      ? detail.map((entry) => entry.msg).join(" · ")
      : typeof detail === "string"
        ? detail
        : "No se pudo completar la operación.";
    throw new ApiError(message, response.status);
  }
  return data;
}

export const api = {
  baseUrl: API_URL,
  login: (username, password) =>
    request("/api/auth/login", { method: "POST", body: { username, password } }),
  me: (token) => request("/api/auth/me", { token }),
  logout: (token) => request("/api/auth/logout", { method: "POST", token }),
  listUsers: (token, { search = "", role = "", active = "", limit = 25, offset = 0 } = {}) => {
    const params = new URLSearchParams();
    if (search.trim()) params.set("search", search.trim());
    if (role) params.set("role", role);
    if (active) params.set("active", active);
    params.set("limit", String(limit));
    params.set("offset", String(offset));
    return request(`/api/admin/users?${params}`, { token });
  },
  userDetail: (token, userId) => request(`/api/admin/users/${userId}`, { token }),
  stats: (token) => request("/api/admin/stats", { token }),
  createUser: (token, payload) =>
    request("/api/admin/users", { method: "POST", token, body: payload }),
  updateUser: (token, userId, payload) =>
    request(`/api/admin/users/${userId}`, { method: "PATCH", token, body: payload }),
  deleteUser: (token, userId) =>
    request(`/api/admin/users/${userId}`, { method: "DELETE", token }),
};
