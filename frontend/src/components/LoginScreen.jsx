import { useState } from "react";

export default function LoginScreen({ onLogin, notice }) {
  const [registering, setRegistering] = useState(false);
  const [identifier, setIdentifier] = useState("");
  const [email, setEmail] = useState("");
  const [fullName, setFullName] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const submit = async (event) => {
    event.preventDefault();
    if (!identifier.trim() || !password || (registering && (!email.trim() || !passwordConfirmation))) {
      setError(registering ? "Completa todos los campos obligatorios." : "Escribe tu usuario y tu contraseña.");
      return;
    }
    if (registering && password !== passwordConfirmation) {
      setError("Las contraseñas no coinciden.");
      return;
    }
    setSubmitting(true);
    setError("");
    try {
      if (registering) {
        await onLogin({
          username: identifier.trim(),
          email: email.trim(),
          full_name: fullName.trim(),
          password
        });
      } else {
        await onLogin(identifier.trim(), password);
      }
    } catch (requestError) {
      setError(requestError.message || "No se pudo iniciar sesión.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="login-shell">
      <section className="login-intro">
        <div className="login-brand">
          <div className="brand-mark">◆</div>
          <div>
            <strong>GALERIS</strong>
            <span>Galerías 3D colaborativas</span>
          </div>
        </div>
        <div className="login-hero">
          <p className="eyebrow">PLATAFORMA DE EXPOSICIONES</p>
          <h1>Diseña, comparte y administra tus galerías en 3D.</h1>
          <p>
            Un único espacio para construir salas, organizar la biblioteca de modelos y
            coordinar a todo el equipo.
          </p>
        </div>
        <ul className="login-features">
          <li><span>✦</span><div><strong>Editor 3D</strong><small>Paredes, bloques y modelos GLB en tiempo real.</small></div></li>
          <li><span>◈</span><div><strong>Modo usuario</strong><small>Cada persona trabaja con sus propios proyectos.</small></div></li>
          <li><span>◉</span><div><strong>Modo administrador</strong><small>Consulta todos los usuarios, roles y actividad.</small></div></li>
        </ul>
        <p className="login-footnote">Proyecto de integración · Galeris</p>
      </section>

      <section className="login-panel">
        <div className="login-card">
          <header>
            <p className="eyebrow">{registering ? "NUEVA CUENTA" : "BIENVENIDO DE NUEVO"}</p>
            <h2>{registering ? "Crear cuenta" : "Iniciar sesión"}</h2>
            <p>{registering ? "Regístrate como usuario para crear tus galerías." : "Accede con tu cuenta para continuar."}</p>
          </header>

          <form onSubmit={submit} noValidate>
            <label className="form-field">
              <span>Usuario o correo</span>
              <input
                type="text"
                name="username"
                autoComplete={registering ? "username" : "username"}
                placeholder={registering ? "mi-usuario" : "admin"}
                value={identifier}
                onChange={(event) => setIdentifier(event.target.value)}
                autoFocus
              />
            </label>

            {registering && (
              <>
                <label className="form-field">
                  <span>Correo electrónico</span>
                  <input type="email" name="email" autoComplete="email" placeholder="tu@correo.com" value={email} onChange={(event) => setEmail(event.target.value)} />
                </label>
                <label className="form-field">
                  <span>Nombre completo <small>(opcional)</small></span>
                  <input type="text" name="full_name" autoComplete="name" placeholder="Tu nombre" value={fullName} onChange={(event) => setFullName(event.target.value)} />
                </label>
              </>
            )}

            <label className="form-field">
              <span>{registering ? "Contraseña (mínimo 8 caracteres)" : "Contraseña"}</span>
              <div className="password-field">
                <input
                  type={showPassword ? "text" : "password"}
                  name="password"
                  autoComplete="current-password"
                  placeholder="••••••••"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                />
                <button
                  type="button"
                  className="password-toggle"
                  onClick={() => setShowPassword((value) => !value)}
                  aria-label={showPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
                >
                  {showPassword ? "Ocultar" : "Ver"}
                </button>
              </div>
            </label>

            {registering && (
              <label className="form-field">
                <span>Confirmar contraseña</span>
                <input type="password" name="password_confirmation" autoComplete="new-password" placeholder="••••••••" value={passwordConfirmation} onChange={(event) => setPasswordConfirmation(event.target.value)} />
              </label>
            )}

            {error && <p className="form-error" role="alert">{error}</p>}
            {notice && !error && <p className="form-notice">{notice}</p>}

            <button className="button primary full" type="submit" disabled={submitting}>
              {submitting ? (registering ? "Creando cuenta…" : "Comprobando…") : (registering ? "Crear cuenta" : "Entrar")}
            </button>
          </form>

          <button type="button" className="login-switch" onClick={() => { setRegistering((value) => !value); setError(""); }}>
            {registering ? "¿Ya tienes una cuenta? Inicia sesión" : "¿No tienes cuenta? Crea una como usuario"}
          </button>

          {!registering && import.meta.env.DEV && (
            <div className="demo-credentials">
              <p className="eyebrow">ACCESO DE DEMOSTRACIÓN</p>
              <p><code>admin</code> / <code>admin123</code> · administrador</p>
              <p><code>marc</code> / <code>galeris123</code> · usuario</p>
            </div>
          )}
        </div>
      </section>
    </main>
  );
}
