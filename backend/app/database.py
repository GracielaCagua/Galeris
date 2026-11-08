import os
from pathlib import Path

from fastapi import Request
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker


class Base(DeclarativeBase):
    pass


def create_database(database_url: str):
    connect_args = {"check_same_thread": False} if database_url.startswith("sqlite") else {}
    if database_url.startswith("sqlite:///"):
        database_path = database_url.removeprefix("sqlite:///")
        if database_path != ":memory:":
            Path(database_path).parent.mkdir(parents=True, exist_ok=True)

    engine = create_engine(database_url, connect_args=connect_args)
    return engine, sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def ensure_owner_columns(engine) -> None:
    """Añade ``owner_id`` a bases de datos SQLite creadas antes de existir usuarios."""

    if engine.dialect.name != "sqlite":
        return
    with engine.begin() as connection:
        for table in ("resources", "projects"):
            columns = {
                row[1] for row in connection.exec_driver_sql(f"PRAGMA table_info({table})")
            }
            if columns and "owner_id" not in columns:
                connection.exec_driver_sql(f"ALTER TABLE {table} ADD COLUMN owner_id INTEGER")



def get_session(request: Request):
    session_factory = request.app.state.session_factory
    with session_factory() as session:
        yield session


def default_database_url() -> str:
    return os.getenv("DATABASE_URL", "sqlite:///./data/gallery.db")