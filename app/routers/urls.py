from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.routers.auth import get_current_user
from app.schemas.analytics import AnalyticsResponse
from app.schemas.url import URLCreate, URLResponse, URLUpdate
from app.services import analytics as analytics_service
from app.services import url as url_service

router = APIRouter(prefix="/urls", tags=["urls"])


def build_url_response(url, base_url: str) -> dict:
    return {
        "id": url.id,
        "original_url": url.original_url,
        "short_code": url.short_code,
        "short_url": f"{base_url}/{url.short_code}",
        "is_active": url.is_active,
        "created_at": url.created_at,
    }


@router.post("", response_model=URLResponse, status_code=status.HTTP_201_CREATED)
def create_url(
    payload: URLCreate,
    db: Session = Depends(get_db),
    current: tuple = Depends(get_current_user),
):
    user, _, _ = current

    try:
        url = url_service.create_short_url(
            db=db,
            original_url=str(payload.original_url),
            owner_id=user.id,
            custom_alias=payload.custom_alias,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return build_url_response(url, settings.BASE_URL)


@router.get("", response_model=list[URLResponse])
def list_urls(
    db: Session = Depends(get_db),
    current: tuple = Depends(get_current_user),
):
    user, _, _ = current
    urls = url_service.get_urls_by_owner(db, user.id)
    return [build_url_response(u, settings.BASE_URL) for u in urls]




@router.patch("/{url_id}", response_model=URLResponse)
def update_url(
    url_id: int,
    payload: URLUpdate,
    db: Session = Depends(get_db),
    current: tuple = Depends(get_current_user),
):
    user, _, _ = current
    url = url_service.get_url_by_id_and_owner(db, url_id, user.id)
    if not url:
        raise HTTPException(status_code=404, detail="URL not found")

    existing = url_service.get_url_by_short_code(db, payload.custom_alias)
    if existing and existing.id != url_id:
        raise HTTPException(status_code=400, detail="Alias already taken")

    url = url_service.update_short_url(db, url, payload.custom_alias)
    return build_url_response(url, settings.BASE_URL)


@router.delete("/{url_id}", status_code=status.HTTP_200_OK)
def delete_url(
    url_id: int,
    db: Session = Depends(get_db),
    current: tuple = Depends(get_current_user),
):
    user, _, _ = current
    url = url_service.get_url_by_id_and_owner(db, url_id, user.id)
    if not url:
        raise HTTPException(status_code=404, detail="URL not found")

    url_service.delete_short_url(db, url)
    return {"message": "URL deleted successfully"}


@router.get("/{url_id}/analytics", response_model=AnalyticsResponse)
def get_analytics(
    url_id: int,
    db: Session = Depends(get_db),
    current: tuple = Depends(get_current_user),
):
    user, _, _ = current
    url = url_service.get_url_by_id_and_owner(db, url_id, user.id)
    if not url:
        raise HTTPException(status_code=404, detail="URL not found")

    return analytics_service.get_analytics(db, url)