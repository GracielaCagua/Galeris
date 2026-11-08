import pytest
from fastapi.testclient import TestClient

from conftest import only_postgres
from sqlalchemy import Column, Integer, MetaData, Table, create_engine, inspect
from sqlalchemy.orm import sessionmaker

from app.database import DatabaseUnavailable, add_missing_columns, default_database_url
from app.main import create_app


@pytest.fixture
def client(tmp_path, database_url):
    app = create_app(database_url=database_url, storage_dir=tmp_path / "storage")
    with TestClient(app) as test_client:
        yield test_client


def stored_files(tmp_path):
    return [path for path in (tmp_path / "storage").rglob("*") if path.is_file()]


def upload(client, filename="obra.png", content=b"contenido", **data):
    return client.post(
        "/api/resources",
        data={"name": "Recurso", **data},
        files={"file": (filename, content)},
    )


def test_default_database_url_uses_postgresql(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)

    assert default_database_url().startswith("postgresql+psycopg://")


def test_database_url_can_be_configured(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "sqlite:///./otra.db")

    assert default_database_url() == "sqlite:///./otra.db"


def test_unreachable_database_fails_with_clear_message_without_password(tmp_path):
    with pytest.raises(DatabaseUnavailable) as error:
        create_app(
            database_url="postgresql+psycopg://galeris:secreta@127.0.0.1:1/galeris",
            storage_dir=tmp_path / "storage",
        )

    assert "127.0.0.1" in str(error.value)
    assert "secreta" not in str(error.value)


def test_database_health_reports_engine(client, database_url):
    response = client.get("/api/health/database")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "engine": database_url.split("+")[0].split(":")[0]}


@pytest.mark.parametrize("path", ["/api/projects", "/api/resources", "/api/health/database"])
def test_database_outage_while_running_returns_503(client, path):
    broken = create_engine(
        "postgresql+psycopg://galeris:secreta@127.0.0.1:1/galeris",
        connect_args={"connect_timeout": 2},
    )
    client.app.state.session_factory = sessionmaker(bind=broken)

    response = client.get(path)

    assert response.status_code == 503
    assert "secreta" not in response.text


def test_add_missing_columns_upgrades_existing_table(database_url):
    engine = create_engine(database_url)
    old = MetaData()
    Table("schema_upgrade_test", old, Column("id", Integer, primary_key=True))
    new = MetaData()
    Table(
        "schema_upgrade_test",
        new,
        Column("id", Integer, primary_key=True),
        Column("owner_id", Integer, nullable=True),
        Column("required", Integer, nullable=False),
    )
    Table("not_created_yet", new, Column("id", Integer, primary_key=True))
    try:
        old.create_all(engine)

        add_missing_columns(engine, new)
        add_missing_columns(engine, new)

        inspector = inspect(engine)
        columns = {column["name"] for column in inspector.get_columns("schema_upgrade_test")}
        assert columns == {"id", "owner_id"}
        assert not inspector.has_table("not_created_yet")
    finally:
        old.drop_all(engine)
        engine.dispose()


@only_postgres
@pytest.mark.parametrize(
    ("method", "path", "kwargs"),
    [
        ("post", "/api/projects", {"json": {"name": "a\x00b"}}),
        ("get", "/api/resources", {"params": {"category": "a\x00b"}}),
        ("post", "/api/resources", {"data": {"name": "a\x00b"}, "files": {"file": ("obra.png", b"x")}}),
    ],
)
def test_text_postgresql_cannot_store_returns_422(client, tmp_path, method, path, kwargs):
    response = getattr(client, method)(path, **kwargs)

    assert response.status_code == 422
    assert stored_files(tmp_path) == []


@only_postgres
def test_project_data_with_nul_character_round_trips(client):
    data = {"nota": "a\u0000b"}

    created = client.post("/api/projects", json={"name": "Sala", "data": data})

    assert created.status_code == 201
    assert client.get(f"/api/projects/{created.json()['id']}").json()["data"] == data


def test_form_with_empty_thumbnail_field_is_accepted(client):
    response = client.post(
        "/api/resources",
        data={"name": "Obra", "thumbnail": ""},
        files={"file": ("obra.png", b"x")},
    )

    assert response.status_code == 201
    assert response.json()["thumbnail_url"] is None


def test_resource_lifecycle_and_project_persistence(client):
    uploaded = client.post(
        "/api/resources",
        data={"name": "Escultura", "type": "model3d", "category": "arte"},
        files={
            "file": ("escultura.glb", b"modelo-de-prueba", "model/gltf-binary"),
            "thumbnail": ("escultura.png", b"miniatura-de-prueba", "image/png"),
        },
    )
    assert uploaded.status_code == 201
    resource = uploaded.json()
    assert resource["path"].startswith("models/")
    assert resource["thumbnail_path"].startswith("thumbnails/")
    assert client.get("/api/resources", params={"category": "arte"}).json()[0]["id"] == resource["id"]
    assert client.get(resource["file_url"]).content == b"modelo-de-prueba"
    assert client.get(resource["thumbnail_url"]).content == b"miniatura-de-prueba"
    assert client.delete(f"/api/resources/{resource['id']}").status_code == 204
    assert client.get(f"/api/resources/{resource['id']}").status_code == 404

    saved = client.post(
        "/api/projects",
        json={"name": "Sala inicial", "data": {"objects": [{"resource_id": resource["id"]}]}},
    )
    assert saved.status_code == 201
    project_id = saved.json()["id"]
    assert client.get(f"/api/projects/{project_id}").json()["data"]["objects"][0]["resource_id"] == resource["id"]


@pytest.mark.parametrize(
    ("filename", "expected_type", "folder"),
    [
        ("obra.PNG", "image", "images/"),
        ("obra.jpeg", "image", "images/"),
        ("obra.webp", "image", "images/"),
        ("modelo.glb", "model3d", "models/"),
        ("modelo.gltf", "model3d", "models/"),
        ("fuente.blend", "blender", "blender/"),
    ],
)
def test_upload_detects_type_and_uses_its_folder(client, filename, expected_type, folder):
    response = upload(client, filename)

    assert response.status_code == 201
    assert response.json()["type"] == expected_type
    assert response.json()["path"].startswith(folder)
    assert response.json()["thumbnail_url"] is None


@pytest.mark.parametrize(
    ("filename", "content", "data"),
    [
        ("virus.exe", b"x", {}),
        ("sin_extension", b"x", {}),
        ("pagina.svg", b"x", {}),
        ("obra.png", b"", {}),
        ("obra.png", b"x", {"type": "model3d"}),
        ("obra.png", b"x", {"type": "desconocido"}),
    ],
)
def test_invalid_upload_is_rejected_without_leaving_files(client, tmp_path, filename, content, data):
    response = upload(client, filename, content, **data)

    assert response.status_code == 422
    assert stored_files(tmp_path) == []
    assert client.get("/api/resources").json() == []


@pytest.mark.parametrize(
    ("thumbnail_name", "thumbnail_content"),
    [("miniatura.exe", b"x"), ("miniatura.png", b"")],
)
def test_invalid_thumbnail_is_rejected_without_leaving_files(client, tmp_path, thumbnail_name, thumbnail_content):
    response = client.post(
        "/api/resources",
        data={"name": "Modelo"},
        files={"file": ("modelo.glb", b"x"), "thumbnail": (thumbnail_name, thumbnail_content)},
    )

    assert response.status_code == 422
    assert stored_files(tmp_path) == []


def test_filename_cannot_escape_storage(client, tmp_path):
    response = upload(client, "../../fuera.png")

    assert response.status_code == 201
    assert ".." not in response.json()["path"]
    assert len(stored_files(tmp_path)) == 1


def test_long_filename_keeps_extension(client):
    response = upload(client, f"{'a' * 400}.png")

    assert response.status_code == 201
    assert response.json()["path"].endswith(".png")
    assert len(response.json()["path"]) < 200


def test_delete_removes_files_from_disk(client, tmp_path):
    resource = client.post(
        "/api/resources",
        data={"name": "Modelo"},
        files={"file": ("modelo.glb", b"x"), "thumbnail": ("miniatura.png", b"y")},
    ).json()
    assert len(stored_files(tmp_path)) == 2

    assert client.delete(f"/api/resources/{resource['id']}").status_code == 204

    assert stored_files(tmp_path) == []


def test_list_filters_by_type(client):
    upload(client, "obra.png")
    upload(client, "modelo.glb")

    listed = client.get("/api/resources", params={"type": "model3d"}).json()

    assert [resource["type"] for resource in listed] == ["model3d"]


def test_missing_stored_file_returns_404(client, tmp_path):
    resource = upload(client, "obra.png").json()
    for path in stored_files(tmp_path):
        path.unlink()

    assert client.get(resource["file_url"]).status_code == 404


def test_resource_without_thumbnail_returns_404(client):
    resource = upload(client, "obra.png").json()

    assert client.get(f"/api/resources/{resource['id']}/thumbnail").status_code == 404


def test_project_update_list_and_delete(client):
    project_id = client.post("/api/projects", json={"name": "Sala", "data": {"paredes": []}}).json()["id"]

    updated = client.put(
        f"/api/projects/{project_id}",
        json={"name": "Sala norte", "description": "Planta baja", "data": {"paredes": [{"id": "pared_1"}]}},
    )

    assert updated.status_code == 200
    assert updated.json()["data"]["paredes"][0]["id"] == "pared_1"
    assert [project["name"] for project in client.get("/api/projects").json()] == ["Sala norte"]
    assert client.delete(f"/api/projects/{project_id}").status_code == 204
    assert client.get(f"/api/projects/{project_id}").status_code == 404
    assert client.put(f"/api/projects/{project_id}", json={"name": "Otra"}).status_code == 404


def test_project_requires_name(client):
    assert client.post("/api/projects", json={"name": ""}).status_code == 422


def test_data_survives_restart(tmp_path, database_url):
    options = {"database_url": database_url, "storage_dir": tmp_path / "storage"}
    with TestClient(create_app(**options)) as first_run:
        resource = upload(first_run, "obra.png", b"persistente").json()
        project_id = first_run.post("/api/projects", json={"name": "Sala"}).json()["id"]

    with TestClient(create_app(**options)) as second_run:
        assert second_run.get(resource["file_url"]).content == b"persistente"
        assert second_run.get(f"/api/projects/{project_id}").json()["name"] == "Sala"


@pytest.mark.parametrize(
    ("origin", "allowed"),
    [
        ("http://localhost:5173", True),
        ("http://127.0.0.1:5173", True),
        ("https://sitio-externo.example", False),
        ("http://localhost.sitio-externo.example", False),
    ],
)
def test_cors_only_allows_local_origins(client, origin, allowed):
    response = client.get("/api/health", headers={"Origin": origin})

    assert ("access-control-allow-origin" in response.headers) is allowed
