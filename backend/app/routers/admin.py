from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select, update
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import Project, Resource, User
from app.routers.resources import serialize_resource
from app.schemas import (
    AdminStats,
    AdminUserDetail,
    ProjectRead,
    UserCreate,
    UserListRead,
    UserRead,
    UserUpdate,
)
from app.security import hash_password, require_admin

router = APIRouter(prefix="/api/admin", tags=["admin"])


def _counts_by_owner(session: Session, model) -> dict[int, int]:
    rows = session.execute(
        select(model.owner_id, func.count(model.id))
        .where(model.owner_id.is_not(None))
        .group_by(model.owner_id)
    ).all()
    return {owner_id: total for owner_id, total in rows}


def serialize_user(user: User, project_counts: dict[int, int], resource_counts: dict[int, int]) -> UserRead:
    return UserRead(
        id=user.id,
        username=user.username,
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        is_active=user.is_active,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
        projects_count=project_counts.get(user.id, 0),
        resources_count=resource_counts.get(user.id, 0),
    )


def find_user(session: Session, user_id: int) -> User:
    user = session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return user


def active_admin_count(session: Session, exclude_id: int | None = None) -> int:
    query = select(func.count(User.id)).where(User.role == "admin", User.is_active.is_(True))
    if exclude_id is not None:
        query = query.where(User.id != exclude_id)
    return session.scalar(query) or 0


def normalize_email(email: str) -> str:
    return email.strip().lower()


def ensure_email_available(session: Session, email: str, user_id: int | None = None) -> None:
    query = select(User).where(User.email == email)
    if user_id is not None:
        query = query.where(User.id != user_id)
    if session.scalar(query) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ese correo ya está registrado")


@router.get("/stats", response_model=AdminStats)
def get_stats(_admin: User = Depends(require_admin), session: Session = Depends(get_session)):
    total_users = session.scalar(select(func.count(User.id))) or 0
    active_users = session.scalar(select(func.count(User.id)).where(User.is_active.is_(True))) or 0
    admins = session.scalar(select(func.count(User.id)).where(User.role == "admin")) or 0
    return AdminStats(
        total_users=total_users,
        admins=admins,
        active_users=active_users,
        inactive_users=total_users - active_users,
        total_projects=session.scalar(select(func.count(Project.id))) or 0,
        total_resources=session.scalar(select(func.count(Resource.id))) or 0,
    )


@router.get("/users", response_model=UserListRead)
def list_users(
    search: str | None = None,
    role: str | None = Query(default=None, pattern="^(admin|user)$"),
    active: bool | None = None,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    _admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
):
    filters = []
    if search:
        term = f"%{search.strip().lower()}%"
        filters.append(
            or_(
                func.lower(User.username).like(term),
                func.lower(User.email).like(term),
                func.lower(User.full_name).like(term),
            )
        )
    if role:
        filters.append(User.role == role)
    if active is not None:
        filters.append(User.is_active.is_(active))

    conditions = filters or []
    total = session.scalar(select(func.count(User.id)).where(*conditions)) or 0
    users = session.scalars(
        select(User).where(*conditions).order_by(User.username.asc()).limit(limit).offset(offset)
    ).all()

    project_counts = _counts_by_owner(session, Project)
    resource_counts = _counts_by_owner(session, Resource)
    return UserListRead(
        items=[serialize_user(user, project_counts, resource_counts) for user in users],
        total=total,
    )


@router.get("/users/{user_id}", response_model=AdminUserDetail)
def get_user_detail(
    user_id: int,
    _admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
):
    user = find_user(session, user_id)
    projects = session.scalars(
        select(Project).where(Project.owner_id == user_id).order_by(Project.updated_at.desc())
    ).all()
    resources = session.scalars(
        select(Resource).where(Resource.owner_id == user_id).order_by(Resource.created_at.desc())
    ).all()
    base = serialize_user(
        user,
        {user_id: len(projects)},
        {user_id: len(resources)},
    )
    return AdminUserDetail(
        **base.model_dump(),
        projects=[ProjectRead.model_validate(project) for project in projects],
        resources=[serialize_resource(resource) for resource in resources],
    )


@router.post("/users", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    _admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
):
    username = payload.username.strip().lower()
    if session.scalar(select(User).where(User.username == username)) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ese nombre de usuario ya existe")
    email = normalize_email(payload.email)
    ensure_email_available(session, email)

    user = User(
        username=username,
        email=email,
        full_name=payload.full_name.strip(),
        password_hash=hash_password(payload.password),
        role=payload.role,
        is_active=payload.is_active,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return serialize_user(user, {}, {})


@router.patch("/users/{user_id}", response_model=UserRead)
def update_user(
    user_id: int,
    payload: UserUpdate,
    admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
):
    user = find_user(session, user_id)
    changes = payload.model_dump(exclude_unset=True)

    if user.id == admin.id and (changes.get("role") == "user" or changes.get("is_active") is False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puedes quitarte el rol de administrador ni desactivar tu propia cuenta",
        )

    removing_admin = user.role == "admin" and (
        changes.get("role") == "user" or changes.get("is_active") is False
    )
    if removing_admin and active_admin_count(session, exclude_id=user.id) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe existir al menos un administrador activo",
        )

    if "email" in changes and changes["email"] is not None:
        email = normalize_email(changes["email"])
        ensure_email_available(session, email, user.id)
        changes["email"] = email
    if "full_name" in changes and changes["full_name"] is not None:
        changes["full_name"] = changes["full_name"].strip()
    if changes.get("password"):
        user.password_hash = hash_password(changes.pop("password"))
    else:
        changes.pop("password", None)

    for key, value in changes.items():
        if value is not None:
            setattr(user, key, value)

    session.commit()
    session.refresh(user)
    project_counts = _counts_by_owner(session, Project)
    resource_counts = _counts_by_owner(session, Resource)
    return serialize_user(user, project_counts, resource_counts)


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
):
    user = find_user(session, user_id)
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="No puedes eliminar tu propia cuenta")
    if user.role == "admin" and user.is_active and active_admin_count(session, exclude_id=user.id) == 0:
        raise HTTPException(status_code=400, detail="Debe existir al menos un administrador activo")

    session.execute(update(Project).where(Project.owner_id == user.id).values(owner_id=None))
    session.execute(update(Resource).where(Resource.owner_id == user.id).values(owner_id=None))
    session.delete(user)
    session.commit()
