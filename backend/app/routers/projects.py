from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import Project
from app.schemas import ProjectRead, ProjectWrite

router = APIRouter(prefix="/api/projects", tags=["projects"])


def find_project(session: Session, project_id: int) -> Project:
    project = session.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    return project


@router.post("", response_model=ProjectRead, status_code=status.HTTP_201_CREATED)
def save_project(payload: ProjectWrite, session: Session = Depends(get_session)):
    project = Project(**payload.model_dump())
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


@router.get("", response_model=list[ProjectRead])
def list_projects(session: Session = Depends(get_session)):
    return session.scalars(select(Project).order_by(Project.updated_at.desc())).all()


@router.get("/{project_id}", response_model=ProjectRead)
def get_project(project_id: int, session: Session = Depends(get_session)):
    return find_project(session, project_id)


@router.put("/{project_id}", response_model=ProjectRead)
def update_project(project_id: int, payload: ProjectWrite, session: Session = Depends(get_session)):
    project = find_project(session, project_id)
    for key, value in payload.model_dump().items():
        setattr(project, key, value)
    session.commit()
    session.refresh(project)
    return project


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project(project_id: int, session: Session = Depends(get_session)):
    project = find_project(session, project_id)
    session.delete(project)
    session.commit()