"""Carga usuarios y proyectos de ejemplo para la demostración.

Uso:
    cd backend
    .venv\\Scripts\\python.exe seed_demo.py
"""

from app.bootstrap import DEMO_PASSWORD, seed_default_admin, seed_demo_data
from app.database import Base, create_database, default_database_url, ensure_owner_columns
from app.models import Project, Resource, User  # noqa: F401


def main() -> None:
    engine, session_factory = create_database(default_database_url())
    Base.metadata.create_all(bind=engine)
    ensure_owner_columns(engine)
    seed_default_admin(session_factory)
    created = seed_demo_data(session_factory)
    engine.dispose()

    if created:
        print(f"Se crearon {created} usuarios de demostración (contraseña: {DEMO_PASSWORD}).")
    else:
        print("Los usuarios de demostración ya existían; no se modificó nada.")
    print("Acceso administrador: admin / admin123")


if __name__ == "__main__":
    main()
