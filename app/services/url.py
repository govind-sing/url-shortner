import secrets

from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.models.url import URL
from app.redis import get_redis


def generate_short_code(length: int = 8) -> str:
    return secrets.token_urlsafe(length)[:length]


def get_url_by_short_code(db: Session, short_code: str) -> URL | None:
    return db.query(URL).filter(URL.short_code == short_code, URL.is_active == True).first()


def get_urls_by_owner(db: Session, owner_id: int) -> list[URL]:
    return db.query(URL).filter(URL.owner_id == owner_id, URL.is_active == True).all()


def get_url_by_id_and_owner(db: Session, url_id: int, owner_id: int) -> URL | None:
    return db.query(URL).filter(URL.id == url_id, URL.owner_id == owner_id).first()




def create_short_url(db: Session, original_url: str, owner_id: int, custom_alias: str | None = None) -> URL:
    if custom_alias:
        url = URL(
            original_url=original_url,
            short_code=custom_alias,
            owner_id=owner_id,
        )
        db.add(url)
        try:
            db.commit()
            db.refresh(url)
            return url
        except IntegrityError:
            db.rollback()
            raise ValueError("Custom alias already taken")

    # auto-generated — retry on collision
    while True:
        short_code = generate_short_code()
        url = URL(
            original_url=original_url,
            short_code=short_code,
            owner_id=owner_id,
        )
        db.add(url)
        try:
            db.commit()
            db.refresh(url)
            return url
        except IntegrityError:
            db.rollback()
            # collision at DB level — regenerate and retry
            continue

def update_short_url(db: Session, url: URL, new_alias: str) -> URL:
    r = get_redis()
    # invalidate old cache entry before changing the code
    r.delete(f"url:{url.short_code}")

    url.short_code = new_alias
    db.commit()
    db.refresh(url)
    return url


def delete_short_url(db: Session, url: URL) -> None:
    r = get_redis()
    # invalidate cache so deleted URLs stop redirecting
    r.delete(f"url:{url.short_code}")

    url.is_active = False
    db.commit()