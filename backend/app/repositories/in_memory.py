from __future__ import annotations

from app.models import KifuItem, ScrapeJob, TrackedSource
from app.repositories.base import ScrapeRepository


class InMemoryScrapeRepository(ScrapeRepository):
    def __init__(self) -> None:
        self._sources: dict[str, TrackedSource] = {}
        self._jobs: dict[str, ScrapeJob] = {}
        self._items_by_source_game_id: dict[tuple[str, str], KifuItem] = {}
        self._items_by_item_id: dict[tuple[str, str], KifuItem] = {}
        self._items_by_hash: dict[tuple[str, str], KifuItem] = {}

    def upsert_tracked_source(self, source: TrackedSource) -> TrackedSource:
        existing = self._sources.get(source.username)
        if existing:
            source = source.model_copy(update={"id": existing.id, "created_at": existing.created_at})
        self._sources[source.username] = source
        return source

    def get_tracked_source(self, username: str) -> TrackedSource | None:
        return self._sources.get(username)

    def delete_tracked_source(self, username: str) -> bool:
        return self._sources.pop(username, None) is not None

    def create_job(self, job: ScrapeJob) -> ScrapeJob:
        self._jobs[job.id] = job
        return job

    def update_job(self, job: ScrapeJob) -> ScrapeJob:
        self._jobs[job.id] = job
        return job

    def get_job(self, job_id: str) -> ScrapeJob | None:
        return self._jobs.get(job_id)

    def list_jobs(self, username: str | None = None, limit: int = 20) -> list[ScrapeJob]:
        jobs = list(self._jobs.values())
        if username is not None:
            jobs = [job for job in jobs if job.username == username]
        jobs.sort(key=lambda job: job.requested_at, reverse=True)
        return jobs[:limit]

    def list_kifu_items(self, username: str, job_id: str | None = None, limit: int = 20) -> list[KifuItem]:
        items = [item for (item_username, _), item in self._items_by_item_id.items() if item_username == username]
        if job_id is not None:
            items = [item for item in items if item.job_id == job_id]
        items.sort(key=lambda item: item.scraped_at, reverse=True)
        return items[:limit]

    def get_kifu_item(self, username: str, item_id: str) -> KifuItem | None:
        return self._items_by_item_id.get((username, item_id))

    def has_kifu_item(self, username: str, source_game_id: str, content_hash: str | None = None) -> bool:
        if (username, source_game_id) in self._items_by_source_game_id:
            return True
        if content_hash and (username, content_hash) in self._items_by_hash:
            return True
        return False

    def upsert_kifu_item(self, item: KifuItem) -> bool:
        source_key = (item.username, item.source_game_id)
        item_key = (item.username, item.id)
        hash_key = (item.username, item.content_hash)
        inserted = source_key not in self._items_by_source_game_id and hash_key not in self._items_by_hash
        self._items_by_source_game_id[source_key] = item
        self._items_by_item_id[item_key] = item
        self._items_by_hash[hash_key] = item
        return inserted
