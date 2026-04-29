from __future__ import annotations

from datetime import datetime, timezone

from app.config import Settings
from app.models import JobStatus, KifuItem, KifuItemSummary, ScrapeJob, ScrapeJobCreate, ScrapeMode, TrackedSource, TrackedSourceCreate, utc_now
from app.repositories.base import ScrapeRepository
from app.services.shogi_extend_client import ShogiExtendClient


class ScrapeService:
    def __init__(self, client: ShogiExtendClient, repository: ScrapeRepository, settings: Settings) -> None:
        self._client = client
        self._repository = repository
        self._settings = settings

    def register_source(self, payload: TrackedSourceCreate) -> TrackedSource:
        existing = self._repository.get_tracked_source(payload.username)
        source = TrackedSource(
            id=existing.id if existing else TrackedSource(username=payload.username).id,
            username=payload.username,
            enabled=payload.enabled,
            site="shogi_extend_swars",
            last_successful_page=existing.last_successful_page if existing else None,
            last_seen_game_id=existing.last_seen_game_id if existing else None,
            last_scraped_at=existing.last_scraped_at if existing else None,
            created_at=existing.created_at if existing else utc_now(),
            updated_at=utc_now(),
        )
        return self._repository.upsert_tracked_source(source)

    def get_source(self, username: str) -> TrackedSource | None:
        return self._repository.get_tracked_source(username)

    def delete_source(self, username: str) -> bool:
        return self._repository.delete_tracked_source(username)

    def create_job(self, payload: ScrapeJobCreate) -> ScrapeJob:
        source = self._repository.get_tracked_source(payload.username)
        if source is None:
            source = self.register_source(TrackedSourceCreate(username=payload.username))
        if not source.enabled:
            raise ValueError(f"Tracked source {payload.username} is disabled")
        job = ScrapeJob(username=payload.username, mode=payload.mode)
        return self._repository.create_job(job)

    def get_job(self, job_id: str) -> ScrapeJob | None:
        return self._repository.get_job(job_id)

    def list_jobs(self, username: str | None = None, limit: int = 20) -> list[ScrapeJob]:
        return self._repository.list_jobs(username=username, limit=limit)

    def list_kifu_items(self, username: str, job_id: str | None = None, limit: int = 20) -> list[KifuItemSummary]:
        items = self._repository.list_kifu_items(username=username, job_id=job_id, limit=limit)
        return [KifuItemSummary.from_item(item) for item in items]

    async def run_job(self, job_id: str) -> ScrapeJob:
        job = self._repository.get_job(job_id)
        if job is None:
            raise ValueError(f"Job {job_id} was not found")

        source = self._repository.get_tracked_source(job.username)
        if source is None:
            raise ValueError(f"Tracked source {job.username} was not found")

        job = job.model_copy(update={"status": JobStatus.running, "started_at": utc_now(), "error_summary": None})
        self._repository.update_job(job)

        try:
            max_page = await self._client.discover_max_page(job.username)
            known_streak = 0
            last_seen_game_id = source.last_seen_game_id
            inserted_games = job.inserted_games
            skipped_games = job.skipped_games
            fetched_games = job.fetched_games

            for page in range(1, max_page + 1):
                crawl_page = await self._client.fetch_search_page(job.username, page)
                if not crawl_page.results:
                    break
                fetched_games += len(crawl_page.results)

                for result in crawl_page.results:
                    if self._repository.has_kifu_item(job.username, result.source_game_id):
                        skipped_games += 1
                        known_streak += 1
                        if job.mode == ScrapeMode.incremental and known_streak >= self._settings.known_streak_stop_count:
                            break
                        continue

                    kif_text, metadata = await self._client.fetch_kif_text(result.detail_url)
                    item = KifuItem.from_scrape(result, kif_text, metadata, job_id=job.id)
                    if self._repository.upsert_kifu_item(item):
                        inserted_games += 1
                        known_streak = 0
                        last_seen_game_id = item.source_game_id
                    else:
                        skipped_games += 1
                        known_streak += 1

                job = job.model_copy(
                    update={
                        "discovered_max_page": max_page,
                        "processed_pages": page,
                        "fetched_games": fetched_games,
                        "inserted_games": inserted_games,
                        "skipped_games": skipped_games,
                    }
                )
                self._repository.update_job(job)

                if job.mode == ScrapeMode.incremental and known_streak >= self._settings.known_streak_stop_count:
                    break

            updated_source = source.model_copy(
                update={
                    "last_successful_page": job.processed_pages or max_page,
                    "last_seen_game_id": last_seen_game_id,
                    "last_scraped_at": utc_now(),
                    "updated_at": utc_now(),
                }
            )
            self._repository.upsert_tracked_source(updated_source)
            job = job.model_copy(update={"status": JobStatus.succeeded, "finished_at": utc_now()})
            return self._repository.update_job(job)
        except Exception as exc:
            job = job.model_copy(update={"status": JobStatus.failed, "finished_at": utc_now(), "error_summary": str(exc)})
            self._repository.update_job(job)
            raise
