from datetime import datetime

from pydantic import BaseModel, HttpUrl


class URLCreate(BaseModel):
    original_url: HttpUrl
    custom_alias: str | None = None


class URLUpdate(BaseModel):
    custom_alias: str


class URLResponse(BaseModel):
    id: int
    original_url: str
    short_code: str
    short_url: str
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}