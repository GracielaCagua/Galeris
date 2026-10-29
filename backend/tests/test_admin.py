import pytest
from fastapi.testclient import TestClient

from app.main import create_app

ADMIN_USER = "root"
ADMIN_PASSWORD = "rootpass123"


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("GALLERIS_ADMIN_USERNAME", ADMIN_USER)
    monkeypatch.setenv("GALLERIS_ADMIN_PASSWORD", ADMIN_PASSWORD)
    app = create_app(
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
        storage_dir=tmp_path / "storage",
    )
    with TestClient(app) as test_client:
        yield test_client


def login(client, username=ADMIN_USER, password=ADMIN_PASSWORD):
    response = client.post("/api/auth/login", json={"username": username, "password": password})
    assert response.status_code == 200, response.text
    return response.json()


def auth_headers(token):
    return {"Authorization": f"Bearer {token}"}


def test_admin_login_and_me(client):
    assert client.post("/api/auth/login", json={"username": ADMIN_USER, "password": "incorrecta"}).status_code == 401

    session = login(client)
    assert session["user"]["role"] == "admin"
    assert session["access_token"]

    me = client.get("/api/auth/me", headers=auth_headers(session["access_token"]))
    assert me.status_code == 200
    assert me.json()["username"] == ADMIN_USER
    assert client.get("/api/auth/me").status_code == 401


def test_admin_user_management(client):
    token = login(client)["access_token"]
    headers = auth_headers(token)

    created = client.post(
        "/api/admin/users",
        headers=headers,
        json={
            "username": "ana.torres",
            "email": "Ana.Torres@example.com",
            "full_name": "Ana Torres",
            "password": "clave-segura-1",
            "role": "user",
        },
    )
    assert created.status_code == 201, created.text
    user = created.json()
    assert user["username"] == "ana.torres"
    assert user["email"] == "ana.torres@example.com"
    assert user["is_active"] is True

    duplicate = client.post(
        "/api/admin/users",
        headers=headers,
        json={
            "username": "ana.torres",
            "email": "otra@example.com",
            "password": "clave-segura-1",
        },
    )
    assert duplicate.status_code == 409

    project = client.post(
        "/api/projects",
        headers=auth_headers(login(client, "ana.torres", "clave-segura-1")["access_token"]),
        json={"name": "Proyecto de Ana", "data": {"objects": []}},
    )
    assert project.status_code == 201

    listing = client.get("/api/admin/users", headers=headers, params={"search": "ana"})
    assert listing.status_code == 200
    assert listing.json()["total"] == 1
    assert listing.json()["items"][0]["projects_count"] == 1

    detail = client.get(f"/api/admin/users/{user['id']}", headers=headers)
    assert detail.status_code == 200
    assert detail.json()["projects"][0]["name"] == "Proyecto de Ana"

    updated = client.patch(
        f"/api/admin/users/{user['id']}",
        headers=headers,
        json={"role": "admin", "full_name": "Ana T."},
    )
    assert updated.status_code == 200
    assert updated.json()["role"] == "admin"
    assert updated.json()["full_name"] == "Ana T."

    stats = client.get("/api/admin/stats", headers=headers)
    assert stats.status_code == 200
    assert stats.json()["total_users"] == 2
    assert stats.json()["admins"] == 2
    assert stats.json()["total_projects"] == 1

    deactivated = client.patch(
        f"/api/admin/users/{user['id']}",
        headers=headers,
        json={"is_active": False},
    )
    assert deactivated.status_code == 200
    assert deactivated.json()["is_active"] is False
    blocked = client.post(
        "/api/auth/login",
        json={"username": "ana.torres", "password": "clave-segura-1"},
    )
    assert blocked.status_code == 403

    assert client.delete(f"/api/admin/users/{user['id']}", headers=headers).status_code == 204
    assert client.get(f"/api/admin/users/{user['id']}", headers=headers).status_code == 404
    # El proyecto queda en la galería general, sin propietario.
    assert client.get(f"/api/projects/{project.json()['id']}").json()["owner_id"] is None


def test_admin_requires_admin_role(client):
    token = login(client)["access_token"]
    headers = auth_headers(token)

    created = client.post(
        "/api/admin/users",
        headers=headers,
        json={
            "username": "visitante",
            "email": "visitante@example.com",
            "password": "clave-segura-1",
        },
    )
    user_session = login(client, "visitante", "clave-segura-1")

    forbidden = client.get("/api/admin/users", headers=auth_headers(user_session["access_token"]))
    assert forbidden.status_code == 403
    assert client.get("/api/admin/users").status_code == 401

    guardian = client.patch(
        "/api/admin/users/1",
        headers=headers,
        json={"role": "user"},
    )
    assert guardian.status_code == 400
    assert "administrador" in guardian.json()["detail"].lower()

    assert client.delete("/api/admin/users/1", headers=headers).status_code == 400
    assert created.status_code == 201


def test_last_active_admin_is_protected(client):
    token = login(client)["access_token"]
    headers = auth_headers(token)
    second = client.post(
        "/api/admin/users",
        headers=headers,
        json={
            "username": "segundo",
            "email": "segundo@example.com",
            "password": "clave-segura-1",
            "role": "admin",
        },
    ).json()
    second_token = login(client, "segundo", "clave-segura-1")["access_token"]

    # El segundo admin intenta quitar el rol al único otro admin activo:
    # el sistema lo permite porque él seguiría siendo administrador.
    assert client.patch(
        "/api/admin/users/1",
        headers=auth_headers(second_token),
        json={"role": "user"},
    ).status_code == 200

    # Ahora "segundo" es el último admin y no puede degradarse a sí mismo.
    denied = client.patch(
        f"/api/admin/users/{second['id']}",
        headers=auth_headers(second_token),
        json={"role": "user"},
    )
    assert denied.status_code == 400
