from datetime import datetime

from pydantic import BaseModel


class AnalyticsResponse(BaseModel):
    short_code: str
    original_url: str
    total_clicks: int
    last_accessed: datetime | None

    model_config = {"from_attributes": True}