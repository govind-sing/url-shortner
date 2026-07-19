from fastapi import FastAPI
from app.routers import auth

app = FastAPI(
    title="URL Shortener",
    description="A RESTful URL shortener service with JWT auth, analytics, and Redis caching.",
    version="1.0.0",
)

app.include_router(auth.router)


@app.get("/health")
def health_check():
    return {"status": "ok"}