import { useCallback, useEffect, useState } from "react";
import AdminPanel from "./components/AdminPanel.jsx";
import LoginScreen from "./components/LoginScreen.jsx";
import Editor from "./Editor.jsx";
import { api, clearStoredSession, loadSession, saveSession } from "./api.js";

export default function App() {
  const [session, setSession] = useState(() => loadSession());
  const [view, setView] = useState(() => (loadSession()?.user?.role === "admin" ? "admin" : "editor"));
  const [checking, setChecking] = useState(() => Boolean(loadSession()));
  const [notice, setNotice] = useState("");
  const [projectToOpen, setProjectToOpen] = useState(null);

  useEffect(() => {
    const stored = loadSession();
    if (!stored) {
      setChecking(false);
      return undefined;
    }
    let cancelled = false;
    api.me(stored.access_token)
      .then((user) => {
        if (cancelled) return;
        const next = { ...stored, user };
        setSession(next);
        saveSession(next);
        if (user.role !== "admin") setView("editor");
      })
      .catch((error) => {
        if (cancelled || error.status !== 401) return;
        clearStoredSession();
        setSession(null);
        setNotice("Tu sesión ha vencido. Vuelve a iniciar sesión.");
      })
      .finally(() => {
        if (!cancelled) setChecking(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const handleLogin = useCallback(async (usernameOrPayload, password) => {
    const result = typeof usernameOrPayload === "string"
      ? await api.login(usernameOrPayload, password)
      : await api.register(usernameOrPayload);
    saveSession(result);
    setSession(result);
    setNotice("");
    setView(result.user.role === "admin" ? "admin" : "editor");
  }, []);

  const handleLogout = useCallback((message = "") => {
    const token = loadSession()?.access_token;
    if (token) api.logout(token).catch(() => {});
    clearStoredSession();
    setSession(null);
    setView("editor");
    setNotice(message);
    setProjectToOpen(null);
  }, []);

  const handleUserUpdated = useCallback((user) => {
    setSession((current) => {
      if (!current) return current;
      const next = { ...current, user };
      saveSession(next);
      return next;
    });
  }, []);

  if (!session) return <LoginScreen onLogin={handleLogin} notice={notice} />;

  if (checking) {
    return (
      <main className="session-loading">
        <div className="brand-mark">◆</div>
        <p>Comprobando tu sesión…</p>
      </main>
    );
  }

  if (session.user.role === "admin" && view === "admin") {
    return (
      <AdminPanel
        session={session}
        onLogout={handleLogout}
        onOpenEditor={() => { setProjectToOpen(null); setView("editor"); }}
        onOpenProject={(project) => { setProjectToOpen(project); setView("editor"); }}
        onUserUpdated={handleUserUpdated}
      />
    );
  }

  return (
    <Editor
      session={session}
      onLogout={handleLogout}
      onOpenAdmin={() => setView("admin")}
      initialProject={projectToOpen}
    />
  );
}
