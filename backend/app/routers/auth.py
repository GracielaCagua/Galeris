from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import User, utc_now
from app.schemas import LoginRequest, RegisterRequest, TokenResponse, UserRead
from app.security import create_access_token, get_current_user, hash_password, verify_password

router = APIRouter(prefix="/api/auth", tags=["auth"])


def normalize_email(email: str) -> str:
    return email.strip().lower()


def session_response(user: User) -> TokenResponse:
    return TokenResponse(
        access_token=create_access_token(user),
        user=UserRead.model_validate(user),
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, session: Session = Depends(get_session)):
    identifier = payload.username.strip().lower()
    user = session.scalar(
        select(User).where(or_(User.username == identifier, User.email == identifier))
    )
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu cuenta está desactivada. Contacta con un administrador.",
        )
    user.last_login_at = utc_now()
    session.commit()
    session.refresh(user)
    return session_response(user)


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, session: Session = Depends(get_session)):
    username = payload.username.strip().lower()
    email = normalize_email(payload.email)
    if session.scalar(select(User).where(User.username == username)) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ese nombre de usuario ya existe")
    if session.scalar(select(User).where(User.email == email)) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ese correo ya está registrado")

    user = User(
        username=username,
        email=email,
        full_name=payload.full_name.strip(),
        password_hash=hash_password(payload.password),
        role="user",
        is_active=True,
        last_login_at=utc_now(),
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return session_response(user)


@router.get("/me", response_model=UserRead)
def me(user: User = Depends(get_current_user)):
    return UserRead.model_validate(user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(_user: User = Depends(get_current_user)):
    # Las sesiones son tokens firmados sin estado; el cliente descarta el token.
    return None
