import shutil
from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile


class LocalFileStorage:
    def __init__(self, root: str | Path):
        self.root = Path(root).resolve()
        (self.root / "resources").mkdir(parents=True, exist_ok=True)
        (self.root / "thumbnails").mkdir(parents=True, exist_ok=True)

    def save(self, upload: UploadFile, folder: str) -> str:
        original_name = Path(upload.filename or "upload").name
        safe_name = "".join(char for char in original_name if char.isalnum() or char in "._-") or "upload"
        relative_path = Path(folder) / f"{uuid4().hex}_{safe_name}"
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