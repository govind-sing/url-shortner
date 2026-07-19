from fastapi import FastAPI
from app.routers import auth, urls, redirect

app = FastAPI(
    title="URL Shortener",
    description="A RESTful URL shortener service with JWT auth, analytics, and Redis caching.",
    version="1.0.0",
)

app.include_router(auth.router)
app.include_router(urls.router)
app.include_router(redirect.router)


@app.get("/health")
def health_check():
    return {"status": "ok"}