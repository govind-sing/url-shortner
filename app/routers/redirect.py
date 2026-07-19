from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from app.database import get_db
from app.redis import get_redis
from app.services import analytics as analytics_service
from app.services import url as url_service

router = APIRouter(tags=["redirect"])

CACHE_TTL = 3600  # 1 hour


@router.get("/{short_code}")
def redirect(
    short_code: str,
    request: Request,
    db: Session = Depends(get_db),
):
    r = get_redis()
    cache_key = f"url:{short_code}"

    # cache hit — skip DB entirely
    original_url = r.get(cache_key)

    if not original_url:
        # cache miss — query DB, then populate cache
        url = url_service.get_url_by_short_code(db, short_code)
        if not url:
            raise HTTPException(status_code=404, detail="Short URL not found")

        original_url = url.original_url
        r.setex(cache_key, CACHE_TTL, original_url)
        url_id = url.id
    else:
        # still need url_id for click recording — lightweight query
        url = url_service.get_url_by_short_code(db, short_code)
        url_id = url.id

    ip = request.client.host if request.client else None
    analytics_service.record_click(db, url_id, ip)

    return RedirectResponse(url=original_url, status_code=302)