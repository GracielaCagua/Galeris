from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import Resource
from app.schemas import ResourceRead
from app.storage import LocalFileStorage

router = APIRouter(prefix="/api/resources", tags=["resources"])


def serialize_resource(resource: Resource) -> dict:
    return {
        "id": resource.id,
        "name": resource.name,
        "type": resource.type,
        "category": resource.category,
        "path": resource.path,
        "thumbnail_path": resource.thumbnail_path,
        "created_at": resource.created_at,
        "file_url": f"/api/resources/{resource.id}/file",
        "thumbnail_url": f"/api/resources/{resource.id}/thumbnail" if resource.thumbnail_path else None,
    }


def find_resource(session: Session, resource_id: int) -> Resource:
    resource = session.get(Resource, resource_id)
    if resource is None:
        raise HTTPException(status_code=404, detail="Recurso no encontrado")
    return resource


@router.post("", response_model=ResourceRead, status_code=status.HTTP_201_CREATED)
def upload_resource(
    request: Request,
    file: UploadFile = File(...),
    name: str = Form(..., min_length=1, max_length=255),
    type: str = Form(..., min_length=1, max_length=80),
    category: str = Form("general", max_length=120),
    thumbnail: UploadFile | None = File(None),
    session: Session = Depends(get_session),
):
    storage: LocalFileStorage = request.app.state.storage
    saved_paths: list[str] = []
    try:
        resource_path = storage.save(file, "resources")
        saved_paths.append(resource_path)
        thumbnail_path = storage.save(thumbnail, "thumbnails") if thumbnail else None
        if thumbnail_path:
            saved_paths.append(thumbnail_path)
        resource = Resource(
            name=name,
            type=type,
            category=category or "general",
            path=resource_path,
            thumbnail_path=thumbnail_path,
        )
        session.add(resource)
        session.commit()
        session.refresh(resource)
        return serialize_resource(resource)
    except Exception:
        session.rollback()
        for path in saved_paths:
            storage.delete(path)
        raise


@router.get("", response_model=list[ResourceRead])
def list_resources(
    request: Request,
    type: str | None = None,
    category: str | None = None,
    session: Session = Depends(get_session),
):
    query = select(Resource).order_by(Resource.created_at.desc())
    if type:
        query = query.where(Resource.type == type)
    if category:
        query = query.where(Resource.category == category)
    return [serialize_resource(resource) for resource in session.scalars(query)]


@router.get("/{resource_id}", response_model=ResourceRead)
def get_resource(resource_id: int, session: Session = Depends(get_session)):
    return serialize_resource(find_resource(session, resource_id))


@router.get("/{resource_id}/file")
def download_resource(resource_id: int, request: Request, session: Session = Depends(get_session)):
    resource = find_resource(session, resource_id)
    path = request.app.state.storage.resolve(resource.path)
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Archivo no encontrado en el almacenamiento")
    return FileResponse(path, filename=Path(path).name)


@router.get("/{resource_id}/thumbnail")
def get_thumbnail(resource_id: int, request: Request, session: Session = Depends(get_session)):
    resource = find_resource(session, resource_id)
    if not resource.thumbnail_path:
        raise HTTPException(status_code=404, detail="El recurso no tiene miniatura")
    path = request.app.state.storage.resolve(resource.thumbnail_path)
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Miniatura no encontrada en el almacenamiento")
    return FileResponse(path)


@router.delete("/{resource_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_resource(resource_id: int, request: Request, session: Session = Depends(get_session)):
    resource = find_resource(session, resource_id)
    storage: LocalFileStorage = request.app.state.storage
    paths = (resource.path, resource.thumbnail_path)
    session.delete(resource)
    session.commit()
    for path in paths:
        storage.delete(path)