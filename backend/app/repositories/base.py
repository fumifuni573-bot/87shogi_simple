from __future__ import annotations

from typing import Protocol

from app.models import KifuItem, ScrapeJob, TrackedSource


class ScrapeRepository(Protocol):
    def upsert_tracked_source(self, source: TrackedSource) -> TrackedSource:
        ...

    def get_tracked_source(self, username: str) -> TrackedSource | None:
        ...

    def delete_tracked_source(self, username: str) -> bool:
        ...

    def create_job(self, job: ScrapeJob) -> ScrapeJob:
        ...

    def update_job(self, job: ScrapeJob) -> ScrapeJob:
        ...

    def get_job(self, job_id: str) -> ScrapeJob | None:
        ...

    def list_jobs(self, username: str | None = None, limit: int = 20) -> list[ScrapeJob]:
        ...

    def list_kifu_items(self, username: str, job_id: str | None = None, limit: int = 20) -> list[KifuItem]:
        ...

    def get_kifu_item(self, username: str, item_id: str) -> KifuItem | None:
        ...

    def has_kifu_item(self, username: str, source_game_id: str, content_hash: str | None = None) -> bool:
        ...

    def upsert_kifu_item(self, item: KifuItem) -> bool:
        ...
