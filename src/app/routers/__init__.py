"""HTTP routers grouped by domain (FastAPI rule 8)."""

from app.routers.greetings import router as greetings_router
from app.routers.health import router as health_router

__all__ = ["greetings_router", "health_router"]
