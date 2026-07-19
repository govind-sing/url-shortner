# URL Shortener Service

A production-ready RESTful URL shortener built with FastAPI, PostgreSQL, and Redis.

## Features

- JWT-based authentication with token revocation on logout
- URL shortening with auto-generated or custom aliases
- Redis-cached redirects for high-throughput performance
- Click analytics with total count and last accessed timestamp
- Fully containerized — one command to run

## Tech Stack

- **FastAPI** — API framework
- **PostgreSQL** — persistent storage
- **Redis** — JWT blacklist + redirect cache
- **SQLAlchemy** — ORM
- **Alembic** — database migrations
- **Docker Compose** — container orchestration

## Schema

```
users         → id, email, username, hashed_password, is_active, created_at
urls          → id, original_url, short_code, is_active, owner_id, created_at
clicks        → id, url_id, ip_address, clicked_at
```

## Getting Started

**Prerequisites:** Docker and Docker Compose installed.

```bash
git clone https://github.com/govind-sing/url-shortener
cd url-shortener
cp .env.example .env
docker-compose up --build
```

Migrations run automatically on startup. API is available at `http://localhost:8000`.

Interactive docs: `http://localhost:8000/docs`

## API Reference

### Auth

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/register` | No | Register a new user |
| POST | `/auth/login` | No | Login, receive JWT |
| POST | `/auth/logout` | Yes | Revoke current token |

### URLs

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/urls` | Yes | Create short URL |
| GET | `/urls` | Yes | List your URLs |
| PATCH | `/urls/{id}` | Yes | Update alias |
| DELETE | `/urls/{id}` | Yes | Delete URL |
| GET | `/urls/{id}/analytics` | Yes | Click analytics |

### Redirect

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/{short_code}` | No | Redirect to original URL |

## curl Examples

### Register
```bash
curl -s -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","username":"yourname","password":"yourpassword"}'
```

### Login
```bash
curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=you@example.com&password=yourpassword"
```

### Shorten a URL
```bash
curl -s -X POST http://localhost:8000/urls \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"original_url":"https://github.com/govind-sing"}'
```

### Shorten with custom alias
```bash
curl -s -X POST http://localhost:8000/urls \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"original_url":"https://google.com","custom_alias":"goog"}'
```

### Redirect
```bash
curl -L http://localhost:8000/<short_code>
```

### List URLs
```bash
curl http://localhost:8000/urls \
  -H "Authorization: Bearer <token>"
```

### Update alias
```bash
curl -s -X PATCH http://localhost:8000/urls/<id> \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"custom_alias":"newname"}'
```

### Delete URL
```bash
curl -s -X DELETE http://localhost:8000/urls/<id> \
  -H "Authorization: Bearer <token>"
```

### Analytics
```bash
curl http://localhost:8000/urls/<id>/analytics \
  -H "Authorization: Bearer <token>"
```

### Logout
```bash
curl -s -X POST http://localhost:8000/auth/logout \
  -H "Authorization: Bearer <token>"
```

## Run Tests

```bash
chmod +x test.sh
./test.sh
```

Runs a full end-to-end test suite covering auth, URL shortening, redirects, cache invalidation, analytics, and token revocation. Every run uses a unique test user so it is safe to run multiple times against a live instance.

## Design Decisions

**Redis for JWT blacklist** — JWTs are stateless so logout requires a blacklist. Redis TTL matches token expiry so entries clean themselves up automatically with no maintenance job needed.

**Redis for redirect cache** — The redirect endpoint is the highest-traffic route. Caching in Redis means most requests never touch PostgreSQL. Cache is invalidated immediately on alias update or delete.

**Cache invalidation on mutation** — When a URL is updated or deleted, the old Redis key is deleted before the DB write commits. This prevents stale redirects.

**IntegrityError retry loop** — Short code generation uses `secrets.token_urlsafe` for unpredictable codes. Collisions are handled at the DB constraint level with an automatic retry, making the system correct under concurrent load.

**Soft delete** — URLs are marked `is_active = False` rather than hard deleted. Preserves click history and analytics data.