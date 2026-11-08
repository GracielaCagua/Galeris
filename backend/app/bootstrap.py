"""Datos iniciales de Galeris: cuenta de administrador y datos de demostración."""

import os
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import sessionmaker

from app.models import Project, User, utc_now
from app.security import hash_password

DEFAULT_ADMIN_USERNAME = "admin"
DEFAULT_ADMIN_PASSWORD = "admin123"
DEFAULT_ADMIN_EMAIL = "admin@galeris.local"
DEMO_PASSWORD = "galeris123"

DEMO_USERS = [
    {
        "username": "laura",
        "email": "laura@galeris.local",
        "full_name": "Laura Méndez",
        "role": "admin",
        "is_active": True,
        "days_ago": 96,
        "projects": [("Galería central", "Sala principal con seis bloques expositivos")],
    },
    {
        "username": "jenny",
        "email": "jenny@galeris.local",
        "full_name": "Jenny Vargas",
        "role": "user",
        "is_active": True,
        "days_ago": 74,
        "projects": [
            ("Sala de esculturas", "Distribución de paredes y pedestales"),
            ("Pasillo norte", "Prueba de iluminación y recorrido"),
        ],
    },
    {
        "username": "pau",
        "email": "pau@galeris.local",
        "full_name": "Pau Ferrer",
        "role": "user",
        "is_active": True,
        "days_ago": 51,
        "projects": [("Módulo giratorio", "Paredes orientables de 90 a 180 grados")],
    },
    {
        "username": "marc",
        "email": "marc@galeris.local",
        "full_name": "Marc Soler",
        "role": "user",
        "is_active": True,
        "days_ago": 33,
        "projects": [
            ("Planta baja", "Cinco bloques de 1 m con muros exteriores"),
            ("Acceso principal", "Revisión de colisiones del recorrido"),
        ],
    },
    {
        "username": "diego",
        "email": "diego@galeris.local",
        "full_name": "Diego Sanz",
        "role": "user",
        "is_active": False,
        "days_ago": 28,
        "projects": [],
    },
    {
        "username": "lucia",
        "email": "lucia@galeris.local",
        "full_name": "Lucía Romero",
        "role": "user",
        "is_active": True,
        "days_ago": 12,
        "projects": [("Sala inmersiva", "Cuadros y lienzos en formato panorámico")],
    },
]


def seed_default_admin(session_factory: sessionmaker) -> User | None:
    """Crea la cuenta administradora inicial si todavía no existe ningún admin."""

    username = os.getenv("GALLERIS_ADMIN_USERNAME", DEFAULT_ADMIN_USERNAME).strip().lower()
    password = os.getenv("GALLERIS_ADMIN_PASSWORD", DEFAULT_ADMIN_PASSWORD)
    email = os.getenv("GALLERIS_ADMIN_EMAIL", DEFAULT_ADMIN_EMAIL).strip().lower()
    full_name = os.getenv("GALLERIS_ADMIN_NAME", "Administrador general")

    with session_factory() as session:
        if session.scalar(select(User).where(User.role == "admin")) is not None:
            return None
        if session.scalar(select(User).where(User.username == username)) is not None:
            return None
        admin = User(
            username=username,
            email=email,
            full_name=full_name,
            password_hash=hash_password(password),
            role="admin",
            is_active=True,
        )
        session.add(admin)
        session.commit()
        session.refresh(admin)
        return admin


def seed_demo_data(session_factory: sessionmaker) -> int:
    """Crea usuarios y proyectos de ejemplo. Es idempotente por nombre de usuario."""

    created = 0
    with session_factory() as session:
        for entry in DEMO_USERS:
            if session.scalar(select(User).where(User.username == entry["username"])) is not None:
                continue
            created_at = utc_now() - timedelta(days=entry["days_ago"])
            user = User(
                username=entry["username"],
                email=entry["email"],
                full_name=entry["full_name"],
                password_hash=hash_password(DEMO_PASSWORD),
                role=entry["role"],
                is_active=entry["is_active"],
                created_at=created_at,
                last_login_at=created_at + timedelta(days=1),
            )
            session.add(user)
            session.flush()
            for index, (name, description) in enumerate(entry["projects"]):
                session.add(
                    Project(
                        name=name,
                        description=description,
                        data={
                            "version": 1,
                            "format": "model-forge-scene",
                            "objects": [
                                {
                                    "instanceId": f"instance-demo-{index + 1}",
                                    "modelId": "model-001",
                                    "position": {"x": 0, "y": 0.5, "z": index * 1.5},
                                    "rotation": {"x": 0, "y": 0, "z": 0},
                                    "scale": {"x": 1, "y": 1, "z": 1},
                                }
                            ],
                        },
                        owner_id=user.id,
                        created_at=created_at,
                        updated_at=created_at + timedelta(days=2),
                    )
                )
            created += 1
        session.commit()
    return created
