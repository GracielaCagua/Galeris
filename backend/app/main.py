import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import Base, create_database, default_database_url
from app.models import Project, Resource
from app.routers import projects, resources
from app.storage import LocalFileStorage


def create_app(database_url: str | None = None, storage_dir: str | Path | None = None) -> FastAPI:
    engine, session_factory = create_database(database_url or default_database_url())
    Base.metadata.create_all(bind=engine)
    storage = LocalFileStorage(storage_dir or os.getenv("GALLERY_STORAGE_DIR", "./storage"))

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        yield
        engine.dispose()

    app = FastAPI(title="Galeris Local API", version="1.0.0", lifespan=lifespan)
    app.state.session_factory = session_factory
    app.state.storage = storage
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(resources.router)
    app.include_router(projects.router)

    @app.get("/api/health", tags=["health"])
    def health():
        return {"status": "ok"}

    return app


app = create_app()