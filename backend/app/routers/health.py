from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_session

router = APIRouter(prefix="/api/health", tags=["health"])


@router.get("/database")
def database_health(session: Session = Depends(get_session)):
    session.execute(text("SELECT 1"))
    return {"status": "ok", "engine": session.get_bind().dialect.name}
