import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.bootstrap import seed_default_admin, seed_demo_data
from app.database import Base, create_database, default_database_url, ensure_owner_columns
from app.models import Project, Resource, User  # noqa: F401  (registra las tablas)
from app.routers import admin, auth, projects, resources
from app.storage import LocalFileStorage


def create_app(database_url: str | None = None, storage_dir: str | Path | None = None) -> FastAPI:
    engine, session_factory = create_database(database_url or default_database_url())
    Base.metadata.create_all(bind=engine)
    ensure_owner_columns(engine)
    storage = LocalFileStorage(storage_dir or os.getenv("GALLERY_STORAGE_DIR", "./storage"))

    seed_default_admin(session_factory)
    if os.getenv("GALLERIS_SEED_DEMO", "").lower() in {"1", "true", "yes"}:
        seed_demo_data(session_factory)

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        yield
        engine.dispose()

    app = FastAPI(title="Galeris Local API", version="1.1.0", lifespan=lifespan)
    app.state.session_factory = session_factory
    app.state.storage = storage
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(auth.router)
    app.include_router(admin.router)
    app.include_router(resources.router)
    app.include_router(projects.router)

    @app.get("/api/health", tags=["health"])
    def health():
        return {"status": "ok", "version": app.version}

    return app


app = create_app()
