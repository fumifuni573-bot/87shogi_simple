from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import BackgroundTasks, FastAPI, HTTPException

from app.config import load_settings
from app.models import KifuItemSummary, ScrapeJob, ScrapeJobCreate, TrackedSource, TrackedSourceCreate
from app.repositories.base import ScrapeRepository
from app.repositories.cosmos import CosmosScrapeRepository
from app.repositories.in_memory import InMemoryScrapeRepository
from app.services.scrape_service import ScrapeService
from app.services.shogi_extend_client import ShogiExtendClient


settings = load_settings()


def build_repository() -> ScrapeRepository:
    if settings.has_cosmos:
        return CosmosScrapeRepository(settings)
    return InMemoryScrapeRepository()


@asynccontextmanager
async def lifespan(_: FastAPI):
    repository = build_repository()
    client = ShogiExtendClient(settings)
    service = ScrapeService(client=client, repository=repository, settings=settings)
    app.state.repository = repository
    app.state.client = client
    app.state.service = service
    try:
        yield
    finally:
        await client.close()


app = FastAPI(title="Shogi Extend Scraper", lifespan=lifespan)


@app.get("/health")
async def health() -> dict[str, str]:
    mode = "cosmos" if settings.has_cosmos else "in-memory"
    return {"status": "ok", "storage": mode}


@app.post("/tracked-sources", response_model=TrackedSource)
async def register_tracked_source(payload: TrackedSourceCreate) -> TrackedSource:
    service: ScrapeService = app.state.service
    return service.register_source(payload)


@app.get("/tracked-sources/{username}", response_model=TrackedSource)
async def get_tracked_source(username: str) -> TrackedSource:
    service: ScrapeService = app.state.service
    source = service.get_source(username)
    if source is None:
        raise HTTPException(status_code=404, detail="tracked source not found")
    return source


@app.delete("/tracked-sources/{username}")
async def delete_tracked_source(username: str) -> dict[str, bool]:
    service: ScrapeService = app.state.service
    deleted = service.delete_source(username)
    return {"deleted": deleted}


@app.post("/scrape-jobs", response_model=ScrapeJob)
async def create_scrape_job(payload: ScrapeJobCreate, background_tasks: BackgroundTasks) -> ScrapeJob:
    service: ScrapeService = app.state.service
    try:
        job = service.create_job(payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    background_tasks.add_task(service.run_job, job.id)
    return job


@app.get("/scrape-jobs/{job_id}", response_model=ScrapeJob)
async def get_scrape_job(job_id: str) -> ScrapeJob:
    service: ScrapeService = app.state.service
    job = service.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    return job


@app.get("/scrape-jobs", response_model=list[ScrapeJob])
async def list_scrape_jobs(username: str | None = None, limit: int = 20) -> list[ScrapeJob]:
    service: ScrapeService = app.state.service
    safe_limit = max(1, min(limit, 100))
    return service.list_jobs(username=username, limit=safe_limit)


@app.get("/kifu-items", response_model=list[KifuItemSummary])
async def list_kifu_items(username: str, job_id: str | None = None, limit: int = 20) -> list[KifuItemSummary]:
    service: ScrapeService = app.state.service
    safe_limit = max(1, min(limit, 100))
    return service.list_kifu_items(username=username, job_id=job_id, limit=safe_limit)