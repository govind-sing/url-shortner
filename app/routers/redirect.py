from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from app.database import get_db
from app.services import analytics as analytics_service
from app.services import url as url_service

router = APIRouter(tags=["redirect"])


@router.get("/{short_code}")
def redirect(
    short_code: str,
    request: Request,
    db: Session = Depends(get_db),
):
    url = url_service.get_url_by_short_code(db, short_code)
    if not url:
        raise HTTPException(status_code=404, detail="Short URL not found")

    ip = request.client.host if request.client else None
    analytics_service.record_click(db, url.id, ip)

    return RedirectResponse(url=url.original_url, status_code=302)