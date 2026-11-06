"""Configuración común de las pruebas.

Las pruebas usan SQLite temporal, así que no hace falta instalar nada. Para
ejecutarlas contra PostgreSQL basta con definir TEST_DATABASE_URL apuntando a una
base vacía y exclusiva para pruebas: sus tablas se borran después de cada prueba.
"""

import os
import tempfile
from pathlib import Path

import pytest
from sqlalchemy import create_engine

_import_dir = Path(tempfile.mkdtemp(prefix="galeris-tests-"))
# app.main crea una aplicación al importarse: nunca debe tocar los datos reales.
os.environ["DATABASE_URL"] = f"sqlite:///{(_import_dir / 'import.db').as_posix()}"
os.environ["GALLERY_STORAGE_DIR"] = str(_import_dir / "storage")

from app.database import Base  # noqa: E402

POSTGRES_URL = os.getenv("TEST_DATABASE_URL")

only_postgres = pytest.mark.skipif(not POSTGRES_URL, reason="Requiere TEST_DATABASE_URL")


@pytest.fixture
def database_url(tmp_path):
    if not POSTGRES_URL:
        yield f"sqlite:///{(tmp_path / 'test.db').as_posix()}"
        return
    yield POSTGRES_URL
    engine = create_engine(POSTGRES_URL)
    Base.metadata.drop_all(engine)
    engine.dispose()
