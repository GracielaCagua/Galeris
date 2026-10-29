from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

USERNAME_PATTERN = r"^[a-zA-Z0-9._-]{3,32}$"
EMAIL_PATTERN = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"

Role = Literal["admin", "user"]


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=255)
    password: str = Field(min_length=1, max_length=128)


class ResourceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    type: str
    category: str
    path: str
    thumbnail_path: str | None
    owner_id: int | None = None
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
    owner_id: int | None = None
    created_at: datetime
    updated_at: datetime


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    email: str
    full_name: str
    role: Role
    is_active: bool
    created_at: datetime
    last_login_at: datetime | None = None
    projects_count: int = 0
    resources_count: int = 0


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=32, pattern=USERNAME_PATTERN)
    email: str = Field(min_length=5, max_length=255, pattern=EMAIL_PATTERN)
    full_name: str = Field(default="", max_length=255)
    password: str = Field(min_length=8, max_length=128)
    role: Role = "user"
    is_active: bool = True


class UserUpdate(BaseModel):
    email: str | None = Field(default=None, min_length=5, max_length=255, pattern=EMAIL_PATTERN)
    full_name: str | None = Field(default=None, max_length=255)
    password: str | None = Field(default=None, min_length=8, max_length=128)
    role: Role | None = None
    is_active: bool | None = None


class UserListRead(BaseModel):
    items: list[UserRead]
    total: int


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserRead


class AdminStats(BaseModel):
    total_users: int
    admins: int
    active_users: int
    inactive_users: int
    total_projects: int
    total_resources: int


class AdminUserDetail(UserRead):
    projects: list[ProjectRead] = Field(default_factory=list)
    resources: list[ResourceRead] = Field(default_factory=list)
