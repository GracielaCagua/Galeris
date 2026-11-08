import { useCallback, useEffect, useRef, useState } from "react";
import {
  api,
  formatDate,
  formatDateTime,
  initials,
  roleLabel,
} from "../api.js";

const EMPTY_FORM = {
  full_name: "",
  username: "",
  email: "",
  password: "",
  role: "user",
  is_active: true,
};

function Avatar({ name, role, small = false }) {
  return (
    <span className={`avatar ${role === "admin" ? "admin" : ""} ${small ? "small" : ""}`}>
      {initials(name)}
    </span>
  );
}

function RoleBadge({ role }) {
  return <span className={`badge role-${role}`}>{roleLabel(role)}</span>;
}

function StatusBadge({ active }) {
  return (
    <span className={`badge status ${active ? "active" : "inactive"}`}>
      <i />
      {active ? "Activo" : "Inactivo"}
    </span>
  );
}

function StatCard({ label, value, hint, accent }) {
  return (
    <article className={`stat-card ${accent || ""}`}>
      <span className="stat-label">{label}</span>
      <strong>{value ?? "—"}</strong>
      {hint && <small>{hint}</small>}
    </article>
  );
}

function UserDialog({ mode, user, isSelf, onClose, onSaved }) {
  const [form, setForm] = useState(() => ({
    ...EMPTY_FORM,
    full_name: user?.full_name || "",
    username: user?.username || "",
    email: user?.email || "",
    role: user?.role || "user",
    is_active: user?.is_active ?? true,
  }));
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  const update = (key) => (event) => {
    const value = event.target.type === "checkbox" ? event.target.checked : event.target.value;
    setForm((current) => ({ ...current, [key]: value }));
  };

  const submit = async (event) => {
    event.preventDefault();
    setError("");
    if (!form.full_name.trim()) return setError("Indica el nombre completo.");
    if (mode === "create" && !/^[a-zA-Z0-9._-]{3,32}$/.test(form.username.trim())) {
      return setError("El usuario debe tener entre 3 y 32 caracteres (letras, números, . _ -).");
    }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(form.email.trim())) {
      return setError("Introduce un correo electrónico válido.");
    }
    if (mode === "create" && form.password.length < 8) {
      return setError("La contraseña debe tener al menos 8 caracteres.");
    }
    if (mode === "edit" && form.password && form.password.length < 8) {
      return setError("La nueva contraseña debe tener al menos 8 caracteres.");
    }

    const payload =
      mode === "create"
        ? {
            full_name: form.full_name.trim(),
            username: form.username.trim().toLowerCase(),
            email: form.email.trim(),
            password: form.password,
            role: form.role,
            is_active: form.is_active,
          }
        : {
            full_name: form.full_name.trim(),
            email: form.email.trim(),
            ...(form.password ? { password: form.password } : {}),
            ...(isSelf ? {} : { role: form.role, is_active: form.is_active }),
          };

    setSaving(true);
    try {
      await onSaved(payload);
    } catch (requestError) {
      setError(requestError.message || "No se pudo guardar el usuario.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <div className="dialog" role="dialog" aria-modal="true" aria-labelledby="user-dialog-title">
        <header className="dialog-header">
          <div>
            <p className="eyebrow">{mode === "create" ? "NUEVO USUARIO" : "EDITAR USUARIO"}</p>
            <h2 id="user-dialog-title">{mode === "create" ? "Crear cuenta" : `@${user.username}`}</h2>
          </div>
          <button type="button" className="icon-button" onClick={onClose} aria-label="Cerrar">×</button>
        </header>

        <form className="dialog-body" onSubmit={submit}>
          <div className="form-row">
            <label className="form-field">
              <span>Nombre completo</span>
              <input value={form.full_name} onChange={update("full_name")} placeholder="Ana Torres" autoFocus />
            </label>
            <label className="form-field">
              <span>Usuario</span>
              <input
                value={form.username}
                onChange={update("username")}
                placeholder="ana.torres"
                disabled={mode === "edit"}
              />
            </label>
          </div>

          <label className="form-field">
            <span>Correo electrónico</span>
            <input type="email" value={form.email} onChange={update("email")} placeholder="ana@galeris.local" />
          </label>

          <label className="form-field">
            <span>{mode === "create" ? "Contraseña" : "Nueva contraseña (opcional)"}</span>
            <input
              type="password"
              value={form.password}
              onChange={update("password")}
              placeholder={mode === "create" ? "Mínimo 8 caracteres" : "Dejar en blanco para mantenerla"}
              autoComplete="new-password"
            />
          </label>

          <div className="form-row">
            <label className="form-field">
              <span>Rol</span>
              <select value={form.role} onChange={update("role")} disabled={isSelf}>
                <option value="user">Usuario</option>
                <option value="admin">Administrador</option>
              </select>
            </label>
            <label className="form-field toggle-field">
              <span>Estado de la cuenta</span>
              <button
                type="button"
                className={`toggle ${form.is_active ? "on" : ""}`}
                onClick={() => !isSelf && setForm((current) => ({ ...current, is_active: !current.is_active }))}
                disabled={isSelf}
                aria-pressed={form.is_active}
              >
                <i />
                {form.is_active ? "Activa" : "Inactiva"}
              </button>
            </label>
          </div>

          {isSelf && <p className="form-hint">No puedes cambiar tu propio rol ni desactivar tu cuenta.</p>}
          {error && <p className="form-error" role="alert">{error}</p>}

          <footer className="dialog-footer">
            <button type="button" className="button secondary" onClick={onClose}>Cancelar</button>
            <button type="submit" className="button primary" disabled={saving}>
              {saving ? "Guardando…" : mode === "create" ? "Crear usuario" : "Guardar cambios"}
            </button>
          </footer>
        </form>
      </div>
    </div>
  );
}

function ConfirmDialog({ user, onClose, onConfirm }) {
  const [working, setWorking] = useState(false);
  const [error, setError] = useState("");

  const confirm = async () => {
    setWorking(true);
    setError("");
    try {
      await onConfirm();
    } catch (requestError) {
      setError(requestError.message || "No se pudo eliminar el usuario.");
      setWorking(false);
    }
  };

  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <div className="dialog small" role="alertdialog" aria-modal="true" aria-labelledby="confirm-title">
        <header className="dialog-header">
          <div>
            <p className="eyebrow">CONFIRMAR ACCIÓN</p>
            <h2 id="confirm-title">Eliminar @{user.username}</h2>
          </div>
          <button type="button" className="icon-button" onClick={onClose} aria-label="Cerrar">×</button>
        </header>
        <div className="dialog-body">
          <p className="dialog-copy">
            La cuenta se eliminará de forma permanente. Sus proyectos y recursos pasarán
            a la galería general sin propietario.
          </p>
          {error && <p className="form-error" role="alert">{error}</p>}
          <footer className="dialog-footer">
            <button type="button" className="button secondary" onClick={onClose}>Cancelar</button>
            <button type="button" className="button destructive" onClick={confirm} disabled={working}>
              {working ? "Eliminando…" : "Eliminar cuenta"}
            </button>
          </footer>
        </div>
      </div>
    </div>
  );
}

export default function AdminPanel({ session, onLogout, onOpenEditor, onUserUpdated }) {
  const token = session.access_token;
  const currentUser = session.user;
  const [users, setUsers] = useState([]);
  const [total, setTotal] = useState(0);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [limit, setLimit] = useState(25);
  const [selectedId, setSelectedId] = useState(null);
  const [detail, setDetail] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [dialog, setDialog] = useState(null);
  const [confirming, setConfirming] = useState(null);
  const [toast, setToast] = useState("");
  const requestSeq = useRef(0);
  const toastTimer = useRef(null);

  const notify = useCallback((message) => {
    setToast(message);
    window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(""), 2800);
  }, []);

  const loadData = useCallback(async () => {
    const seq = ++requestSeq.current;
    setLoading(true);
    setError("");
    try {
      const [list, summary] = await Promise.all([
        api.listUsers(token, {
          search,
          role: roleFilter,
          active: statusFilter,
          limit,
        }),
        api.stats(token),
      ]);
      if (seq !== requestSeq.current) return;
      setUsers(list.items);
      setTotal(list.total);
      setStats(summary);
    } catch (requestError) {
      if (seq !== requestSeq.current) return;
      if (requestError.status === 401) {
        onLogout("Tu sesión ha vencido. Vuelve a iniciar sesión.");
        return;
      }
      setError(requestError.message);
    } finally {
      if (seq === requestSeq.current) setLoading(false);
    }
  }, [token, search, roleFilter, statusFilter, limit, onLogout]);

  useEffect(() => {
    const timer = window.setTimeout(loadData, search ? 260 : 0);
    return () => window.clearTimeout(timer);
  }, [loadData, search]);

  useEffect(() => {
    if (!selectedId) {
      setDetail(null);
      return undefined;
    }
    let cancelled = false;
    setDetailLoading(true);
    api.userDetail(token, selectedId)
      .then((data) => {
        if (!cancelled) setDetail(data);
      })
      .catch((requestError) => {
        if (!cancelled) notify(requestError.message);
      })
      .finally(() => {
        if (!cancelled) setDetailLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [token, selectedId, notify]);

  useEffect(() => () => window.clearTimeout(toastTimer.current), []);

  const reloadDetail = async (userId) => {
    try {
      const data = await api.userDetail(token, userId);
      setDetail(data);
    } catch {
      setDetail(null);
      setSelectedId(null);
    }
  };

  const handleSaved = async (payload) => {
    if (dialog.mode === "create") {
      const created = await api.createUser(token, payload);
      setDialog(null);
      notify(`Usuario @${created.username} creado`);
      setSelectedId(created.id);
    } else {
      const updated = await api.updateUser(token, dialog.user.id, payload);
      setDialog(null);
      if (updated.id === currentUser.id && payload.password) {
        notify("Contraseña actualizada");
        onLogout("Tu contraseña ha cambiado. Inicia sesión de nuevo.");
        return;
      }
      notify("Cambios guardados");
      if (updated.id === currentUser.id) onUserUpdated(updated);
      if (selectedId === updated.id) reloadDetail(updated.id);
    }
    await loadData();
  };

  const toggleActive = async (user) => {
    try {
      await api.updateUser(token, user.id, { is_active: !user.is_active });
      notify(user.is_active ? `@${user.username} desactivado` : `@${user.username} activado`);
      await loadData();
      if (selectedId === user.id) reloadDetail(user.id);
    } catch (requestError) {
      notify(requestError.message);
    }
  };

  const toggleRole = async (user) => {
    const nextRole = user.role === "admin" ? "user" : "admin";
    try {
      const updated = await api.updateUser(token, user.id, { role: nextRole });
      notify(`@${user.username} ahora es ${roleLabel(nextRole).toLowerCase()}`);
      if (updated.id === currentUser.id) onUserUpdated(updated);
      await loadData();
      if (selectedId === user.id) reloadDetail(user.id);
    } catch (requestError) {
      notify(requestError.message);
    }
  };

  const deleteUser = async () => {
    await api.deleteUser(token, confirming.id);
    notify(`Usuario @${confirming.username} eliminado`);
    setConfirming(null);
    if (selectedId === confirming.id) setSelectedId(null);
    await loadData();
  };

  const activeFilters = Boolean(search || roleFilter || statusFilter);
  const clearFilters = () => {
    setSearch("");
    setRoleFilter("");
    setStatusFilter("");
    setLimit(25);
  };

  return (
    <div className="admin-shell">
      <header className="admin-topbar">
        <div className="brand">
          <div className="brand-mark">◆</div>
          <div>
            <strong>GALERIS</strong>
            <span>Panel de administración</span>
          </div>
        </div>
        <span className="admin-badge">MODO ADMINISTRADOR</span>
        <div className="admin-topbar-actions">
          <button type="button" className="button secondary" onClick={onOpenEditor}>Abrir editor 3D</button>
          <div className="session-chip">
            <Avatar name={currentUser.full_name || currentUser.username} role={currentUser.role} small />
            <div>
              <strong>{currentUser.full_name || currentUser.username}</strong>
              <small>{roleLabel(currentUser.role)}</small>
            </div>
          </div>
          <button type="button" className="button danger" onClick={() => onLogout()}>Salir</button>
        </div>
      </header>

      <main className="admin-content">
        <div className="admin-heading">
          <div>
            <p className="eyebrow">GESTIÓN DE LA COMUNIDAD</p>
            <h1>Usuarios de Galeris</h1>
            <p>Consulta todas las cuentas, sus roles, su estado y la actividad de cada persona.</p>
          </div>
          <div className="admin-heading-actions">
            <button type="button" className="button secondary" onClick={loadData} disabled={loading}>
              ↻ Actualizar
            </button>
            <button type="button" className="button primary" onClick={() => setDialog({ mode: "create", user: null })}>
              + Nuevo usuario
            </button>
          </div>
        </div>

        {error && (
          <div className="admin-alert" role="alert">
            <span>{error}</span>
            <button type="button" className="button secondary" onClick={loadData}>Reintentar</button>
          </div>
        )}

        <section className="stats-grid" aria-label="Resumen general">
          <StatCard label="Usuarios totales" value={stats?.total_users} hint="Cuentas registradas" accent="accent" />
          <StatCard label="Administradores" value={stats?.admins} hint="Con acceso completo" />
          <StatCard label="Cuentas activas" value={stats?.active_users} hint="Pueden iniciar sesión" accent="success" />
          <StatCard label="Cuentas inactivas" value={stats?.inactive_users} hint="Acceso bloqueado" />
          <StatCard label="Proyectos" value={stats?.total_projects} hint="Escenas guardadas" />
          <StatCard label="Recursos" value={stats?.total_resources} hint="Modelos en la biblioteca" />
        </section>

        <div className={`admin-layout ${detail ? "with-detail" : ""}`}>
          <section className="users-panel">
            <div className="users-toolbar">
              <label className="search-field">
                <span aria-hidden="true">⌕</span>
                <input
                  type="search"
                  placeholder="Buscar por nombre, usuario o correo…"
                  value={search}
                  onChange={(event) => { setSearch(event.target.value); setLimit(25); }}
                />
              </label>
              <label className="filter-field">
                <span>Rol</span>
                <select value={roleFilter} onChange={(event) => { setRoleFilter(event.target.value); setLimit(25); }}>
                  <option value="">Todos</option>
                  <option value="admin">Administradores</option>
                  <option value="user">Usuarios</option>
                </select>
              </label>
              <label className="filter-field">
                <span>Estado</span>
                <select value={statusFilter} onChange={(event) => { setStatusFilter(event.target.value); setLimit(25); }}>
                  <option value="">Todos</option>
                  <option value="true">Activos</option>
                  <option value="false">Inactivos</option>
                </select>
              </label>
              {activeFilters && (
                <button type="button" className="link-button" onClick={clearFilters}>Limpiar filtros</button>
              )}
            </div>

            <div className="table-wrap">
              <table className="users-table">
                <thead>
                  <tr>
                    <th>Usuario</th>
                    <th>Rol</th>
                    <th>Estado</th>
                    <th className="numeric">Proyectos</th>
                    <th className="numeric">Recursos</th>
                    <th>Último acceso</th>
                    <th className="actions-column">Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {loading && users.length === 0 && (
                    <tr><td colSpan="7" className="table-message">Cargando usuarios…</td></tr>
                  )}
                  {!loading && users.length === 0 && (
                    <tr>
                      <td colSpan="7" className="table-message">
                        {activeFilters ? "Ningún usuario coincide con los filtros." : "Todavía no hay usuarios registrados."}
                      </td>
                    </tr>
                  )}
                  {users.map((user) => (
                    <tr
                      key={user.id}
                      className={`${selectedId === user.id ? "selected" : ""} ${user.is_active ? "" : "is-inactive"}`}
                      onClick={() => setSelectedId(user.id)}
                      tabIndex={0}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          setSelectedId(user.id);
                        }
                      }}
                    >
                      <td>
                        <div className="table-user">
                          <Avatar name={user.full_name || user.username} role={user.role} small />
                          <div>
                            <strong>{user.full_name || user.username}{user.id === currentUser.id && <span className="you-tag">tú</span>}</strong>
                            <small>@{user.username} · {user.email}</small>
                          </div>
                        </div>
                      </td>
                      <td><RoleBadge role={user.role} /></td>
                      <td><StatusBadge active={user.is_active} /></td>
                      <td className="numeric">{user.projects_count}</td>
                      <td className="numeric">{user.resources_count}</td>
                      <td className="nowrap muted-cell">{formatDateTime(user.last_login_at)}</td>
                      <td className="actions-column">
                        <div className="row-actions" onClick={(event) => event.stopPropagation()}>
                          <button type="button" className="icon-action" title="Editar" aria-label={`Editar ${user.username}`} onClick={() => setDialog({ mode: "edit", user })}>✎</button>
                          <button
                            type="button"
                            className="icon-action"
                            title={user.is_active ? "Desactivar" : "Activar"}
                            aria-label={`${user.is_active ? "Desactivar" : "Activar"} ${user.username}`}
                            disabled={user.id === currentUser.id}
                            onClick={() => toggleActive(user)}
                          >
                            {user.is_active ? "⊘" : "✓"}
                          </button>
                          <button
                            type="button"
                            className="icon-action danger"
                            title="Eliminar"
                            aria-label={`Eliminar ${user.username}`}
                            disabled={user.id === currentUser.id}
                            onClick={() => setConfirming(user)}
                          >
                            ×
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <footer className="table-footer">
              <span>Mostrando {users.length} de {total} {total === 1 ? "usuario" : "usuarios"}</span>
              {users.length < total && (
                <button type="button" className="button secondary" onClick={() => setLimit((value) => value + 25)} disabled={loading}>
                  Cargar más
                </button>
              )}
            </footer>
          </section>

          <aside className={`user-detail ${detail ? "open" : ""}`} aria-live="polite">
            {!detail && !detailLoading && (
              <div className="detail-empty">
                <span className="detail-empty-icon">◉</span>
                <h3>Detalle del usuario</h3>
                <p>Selecciona una persona de la lista para ver su ficha, sus proyectos y sus recursos.</p>
              </div>
            )}
            {detailLoading && <div className="detail-empty"><p>Cargando ficha…</p></div>}
            {detail && (
              <>
                <header className="detail-header">
                  <button type="button" className="icon-button close" onClick={() => setSelectedId(null)} aria-label="Cerrar detalle">×</button>
                  <Avatar name={detail.full_name || detail.username} role={detail.role} />
                  <div>
                    <h3>{detail.full_name || detail.username}</h3>
                    <p>@{detail.username}</p>
                    <div className="detail-badges">
                      <RoleBadge role={detail.role} />
                      <StatusBadge active={detail.is_active} />
                    </div>
                  </div>
                </header>

                <dl className="detail-meta">
                  <div><dt>Correo</dt><dd>{detail.email}</dd></div>
                  <div><dt>Alta</dt><dd>{formatDate(detail.created_at)}</dd></div>
                  <div><dt>Último acceso</dt><dd>{formatDateTime(detail.last_login_at)}</dd></div>
                  <div><dt>Identificador</dt><dd>#{detail.id}</dd></div>
                </dl>

                <div className="detail-stats">
                  <div><strong>{detail.projects_count}</strong><span>Proyectos</span></div>
                  <div><strong>{detail.resources_count}</strong><span>Recursos</span></div>
                </div>

                <div className="detail-actions">
                  <button type="button" className="button secondary" onClick={() => setDialog({ mode: "edit", user: detail })}>Editar cuenta</button>
                  <button
                    type="button"
                    className="button secondary"
                    disabled={detail.id === currentUser.id}
                    onClick={() => toggleRole(detail)}
                  >
                    {detail.role === "admin" ? "Quitar administrador" : "Hacer administrador"}
                  </button>
                  <button
                    type="button"
                    className="button secondary"
                    disabled={detail.id === currentUser.id}
                    onClick={() => toggleActive(detail)}
                  >
                    {detail.is_active ? "Desactivar cuenta" : "Activar cuenta"}
                  </button>
                  <button
                    type="button"
                    className="button danger full"
                    disabled={detail.id === currentUser.id}
                    onClick={() => setConfirming(detail)}
                  >
                    Eliminar cuenta
                  </button>
                </div>

                <section className="detail-section">
                  <div className="detail-section-heading">
                    <h4>Proyectos</h4>
                    <span className="count-badge">{detail.projects.length}</span>
                  </div>
                  {detail.projects.length === 0 ? (
                    <p className="detail-empty-text">Este usuario todavía no ha guardado proyectos.</p>
                  ) : (
                    <ul className="detail-list">
                      {detail.projects.slice(0, 6).map((project) => (
                        <li key={project.id}>
                          <span className="project-dot" />
                          <div>
                            <strong>{project.name}</strong>
                            <small>Actualizado el {formatDate(project.updated_at)}</small>
                          </div>
                        </li>
                      ))}
                    </ul>
                  )}
                </section>

                <section className="detail-section">
                  <div className="detail-section-heading">
                    <h4>Recursos</h4>
                    <span className="count-badge">{detail.resources.length}</span>
                  </div>
                  {detail.resources.length === 0 ? (
                    <p className="detail-empty-text">Sin modelos propios en la biblioteca.</p>
                  ) : (
                    <ul className="detail-list">
                      {detail.resources.slice(0, 6).map((resource) => (
                        <li key={resource.id}>
                          <span className="project-dot resource" />
                          <div>
                            <strong>{resource.name}</strong>
                            <small>{resource.category} · {formatDate(resource.created_at)}</small>
                          </div>
                        </li>
                      ))}
                    </ul>
                  )}
                </section>
              </>
            )}
          </aside>
        </div>
      </main>

      {dialog && (
        <UserDialog
          mode={dialog.mode}
          user={dialog.user}
          isSelf={dialog.user?.id === currentUser.id}
          onClose={() => setDialog(null)}
          onSaved={handleSaved}
        />
      )}
      {confirming && (
        <ConfirmDialog
          user={confirming}
          onClose={() => setConfirming(null)}
          onConfirm={deleteUser}
        />
      )}
      {toast && <div className="toast visible">{toast}</div>}
    </div>
  );
}
