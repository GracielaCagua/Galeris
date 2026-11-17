import shutil
from pathlib import Path
from typing import Protocol
from uuid import uuid4

from fastapi import UploadFile

MAX_NAME_LENGTH = 100
STORAGE_FOLDERS = ("images", "models", "blender", "thumbnails")


class FileStorage(Protocol):
    """Contrato que debe cumplir cualquier almacenamiento, local o en la nube."""

    def save(self, upload: UploadFile, folder: str) -> str:
        """Guarda el archivo y devuelve su ruta relativa."""
        ...

    def resolve(self, relative_path: str) -> Path:
        """Devuelve una ruta local legible; en la nube, una copia descargada."""
        ...

    def delete(self, relative_path: str | None) -> None: ...


class LocalFileStorage:
    def __init__(self, root: str | Path):
        self.root = Path(root).resolve()
        for folder in STORAGE_FOLDERS:
            (self.root / folder).mkdir(parents=True, exist_ok=True)

    def save(self, upload: UploadFile, folder: str) -> str:
        original_name = Path(upload.filename or "upload").name
        safe_name = "".join(char for char in original_name if char.isalnum() or char in "._-") or "upload"
        # Se conserva el final del nombre para no perder la extensión al recortarlo.
        relative_path = Path(folder) / f"{uuid4().hex}_{safe_name[-MAX_NAME_LENGTH:]}"
        destination = self._resolve(relative_path.as_posix())
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("wb") as output:
            shutil.copyfileobj(upload.file, output)
        return relative_path.as_posix()

    def resolve(self, relative_path: str) -> Path:
        return self._resolve(relative_path)

    def delete(self, relative_path: str | None) -> None:
        if relative_path:
            self._resolve(relative_path).unlink(missing_ok=True)

    def _resolve(self, relative_path: str) -> Path:
        destination = (self.root / relative_path).resolve()
        if not destination.is_relative_to(self.root):
            raise ValueError("La ruta del recurso no pertenece al almacenamiento configurado")
        return destination