from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ResourceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    type: str
    category: str
    path: str
    thumbnail_path: str | None
    created_at: datetime
    file_url: str
    thumbnail_url: str | None


class ProjectWrite(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str = ""
    data: dict = Field(default_factory=dict)


class ProjectRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    data: dict
    created_at: datetime
    updated_at: datetime