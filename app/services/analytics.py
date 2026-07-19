from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.click import Click
from app.models.url import URL


def record_click(db: Session, url_id: int, ip_address: str | None) -> None:
    click = Click(
        url_id=url_id,
        ip_address=ip_address,
        clicked_at=datetime.now(timezone.utc),
    )
    db.add(click)
    db.commit()


def get_analytics(db: Session, url: URL) -> dict:
    clicks = db.query(Click).filter(Click.url_id == url.id).all()
    total = len(clicks)
    last_accessed = max((c.clicked_at for c in clicks), default=None)
    return {
        "short_code": url.short_code,
        "original_url": url.original_url,
        "total_clicks": total,
        "last_accessed": last_accessed,
    }