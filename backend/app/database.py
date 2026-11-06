import logging
import os
from pathlib import Path

from fastapi import Request
from sqlalchemy import MetaData, create_engine, inspect
from sqlalchemy.engine import Engine
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from sqlalchemy.schema import CreateColumn
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Sin este límite, un servidor que no responde bloquearía la API indefinidamente.
CONNECT_TIMEOUT_SECONDS = 5


class DatabaseUnavailable(RuntimeError):
    """La base de datos configurada no responde al iniciar la API."""


class Base(DeclarativeBase):
    pass


def _checked(engine: Engine) -> Engine:
    try:
        engine.connect().close()
    except OperationalError:
        safe_url = engine.url.render_as_string(hide_password=True)
        raise DatabaseUnavailable(
            f"No se pudo conectar a la base de datos {safe_url}. "
            "Comprueba que el servidor esté encendido y revisa DATABASE_URL (ver docs/backend.md)."
        ) from None
    return engine


def add_missing_columns(engine: Engine, metadata: MetaData) -> None:
    """Añade a las tablas existentes las columnas opcionales nuevas de los modelos.

    create_all solo crea tablas completas, de modo que una base creada antes de una
    columna nueva fallaría al usarla. Las claves foráneas no se añaden, y las columnas
    obligatorias se dejan para una migración porque necesitan un valor para las filas.
    """
    inspector = inspect(engine)
    with engine.begin() as connection:
        for table in metadata.sorted_tables:
            if not inspector.has_table(table.name):
                continue
            existing = {column["name"] for column in inspector.get_columns(table.name)}
            for column in table.columns:
                if column.name in existing:
                    continue
                if not column.nullable:
                    logger.warning("Falta la columna obligatoria %s.%s", table.name, column.name)
                    continue
                definition = CreateColumn(column).compile(dialect=engine.dialect)
                table_name = engine.dialect.identifier_preparer.format_table(table)
                connection.exec_driver_sql(f"ALTER TABLE {table_name} ADD COLUMN {definition}")


def create_database(database_url: str):
    connect_args = (
        {"check_same_thread": False}
        if database_url.startswith("sqlite")
        else {"connect_timeout": CONNECT_TIMEOUT_SECONDS}
    )
    if database_url.startswith("sqlite:///"):
        database_path = database_url.removeprefix("sqlite:///")
        if database_path != ":memory:":
            Path(database_path).parent.mkdir(parents=True, exist_ok=True)

    engine = create_engine(database_url, connect_args=connect_args, pool_pre_ping=True)
    add_missing_columns(_checked(engine), Base.metadata)
    return engine, sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_session(request: Request):
    session_factory = request.app.state.session_factory
    with session_factory() as session:
        yield session


def default_database_url() -> str:
    return os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg://galeris:galeris@localhost:5432/galeris",
    )