from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import Project, User
from app.schemas import ProjectRead, ProjectWrite
from app.security import get_optional_user

router = APIRouter(prefix="/api/projects", tags=["projects"])


def find_project(session: Session, project_id: int) -> Project:
    project = session.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    return project


def ensure_can_access(project: Project, user: User | None) -> None:
    if user and user.role != "admin" and project.owner_id not in (None, user.id):
        raise HTTPException(status_code=403, detail="No tienes acceso a este proyecto")


@router.post("", response_model=ProjectRead, status_code=status.HTTP_201_CREATED)
def save_project(
    payload: ProjectWrite,
    session: Session = Depends(get_session),
    current_user: User | None = Depends(get_optional_user),
):
    project = Project(**payload.model_dump(), owner_id=current_user.id if current_user else None)
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


@router.get("", response_model=list[ProjectRead])
def list_projects(
    session: Session = Depends(get_session),
    current_user: User | None = Depends(get_optional_user),
):
    query = select(Project).order_by(Project.updated_at.desc())
    if current_user and current_user.role != "admin":
        query = query.where(Project.owner_id == current_user.id)
    return session.scalars(query).all()


@router.get("/{project_id}", response_model=ProjectRead)
def get_project(
    project_id: int,
    session: Session = Depends(get_session),
    current_user: User | None = Depends(get_optional_user),
):
    project = find_project(session, project_id)
    ensure_can_access(project, current_user)
    return project


@router.put("/{project_id}", response_model=ProjectRead)
def update_project(
    project_id: int,
    payload: ProjectWrite,
    session: Session = Depends(get_session),
    current_user: User | None = Depends(get_optional_user),
):
    project = find_project(session, project_id)
    ensure_can_access(project, current_user)
    for key, value in payload.model_dump().items():
        setattr(project, key, value)
    session.commit()
    session.refresh(project)
    return project


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project(
    project_id: int,
    session: Session = Depends(get_session),
    current_user: User | None = Depends(get_optional_user),
):
    project = find_project(session, project_id)
    ensure_can_access(project, current_user)
    session.delete(project)
    session.commit()
