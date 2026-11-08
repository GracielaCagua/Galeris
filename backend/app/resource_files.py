"""Reglas de los archivos que acepta el repositorio de recursos."""

from pathlib import Path
from typing import Literal

from fastapi import HTTPException, UploadFile

ResourceType = Literal["image", "model3d", "blender"]

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
EXTENSIONS_BY_TYPE: dict[str, set[str]] = {
    "image": IMAGE_EXTENSIONS,
    "model3d": {".glb", ".gltf"},
    "blender": {".blend"},
}
FOLDER_BY_TYPE = {"image": "images", "model3d": "models", "blender": "blender"}


def _invalid(detail: str) -> HTTPException:
    return HTTPException(status_code=422, detail=detail)


def _extension_of(upload: UploadFile) -> str:
    return Path(upload.filename or "").suffix.lower()


def resolve_resource_type(upload: UploadFile, requested: str | None) -> str:
    """Devuelve el tipo según la extensión; rechaza formatos y tipos que no coinciden."""
    extension = _extension_of(upload)
    detected = next((kind for kind, extensions in EXTENSIONS_BY_TYPE.items() if extension in extensions), None)
    if detected is None:
        allowed = sorted(set().union(*EXTENSIONS_BY_TYPE.values()))
        raise _invalid(f"Formato '{extension}' no permitido. Formatos aceptados: {', '.join(allowed)}")
    if requested and requested != detected:
        raise _invalid(f"Un archivo '{extension}' no puede registrarse como tipo '{requested}'")
    if upload.size == 0:
        raise _invalid("El archivo está vacío")
    return detected


def validate_thumbnail(thumbnail: UploadFile) -> None:
    if _extension_of(thumbnail) not in IMAGE_EXTENSIONS:
        raise _invalid("La miniatura debe ser una imagen JPG, PNG o WEBP")
    if thumbnail.size == 0:
        raise _invalid("La miniatura está vacía")
