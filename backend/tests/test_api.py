from fastapi.testclient import TestClient

from app.main import create_app
from app.database import default_database_url


def test_default_database_url_uses_postgresql(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)

    assert default_database_url().startswith("postgresql+psycopg://")


def test_resource_lifecycle_and_project_persistence(tmp_path):
    app = create_app(
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
        storage_dir=tmp_path / "storage",
    )
    with TestClient(app) as client:
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
        assert resource["path"].startswith("resources/")
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