from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from hashlib import sha256
import re
from typing import Any
from uuid import uuid4

from pydantic import BaseModel, Field


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ScrapeMode(str, Enum):
    full = "full"
    incremental = "incremental"


class JobStatus(str, Enum):
    queued = "queued"
    running = "running"
    succeeded = "succeeded"
    failed = "failed"


class TrackedSource(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid4()))
    username: str
    site: str = "shogi_extend_swars"
    enabled: bool = True
    last_successful_page: int | None = None
    last_seen_game_id: str | None = None
    last_scraped_at: datetime | None = None
    created_at: datetime = Field(default_factory=utc_now)
    updated_at: datetime = Field(default_factory=utc_now)


class TrackedSourceCreate(BaseModel):
    username: str = Field(min_length=1)
    enabled: bool = True


class ScrapeJob(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid4()))
    username: str
    mode: ScrapeMode
    status: JobStatus = JobStatus.queued
    requested_at: datetime = Field(default_factory=utc_now)
    started_at: datetime | None = None
    finished_at: datetime | None = None
    discovered_max_page: int | None = None
    processed_pages: int = 0
    fetched_games: int = 0
    inserted_games: int = 0
    skipped_games: int = 0
    error_summary: str | None = None


class ScrapeJobCreate(BaseModel):
    username: str = Field(min_length=1)
    mode: ScrapeMode = ScrapeMode.incremental


class SearchResult(BaseModel):
    username: str
    page: int
    detail_url: str
    source_game_id: str
    match_date_label: str | None = None


class KifuItem(BaseModel):
    id: str
    username: str
    job_id: str | None = None
    source_game_id: str
    source_game_url: str
    searched_page: int
    scraped_at: datetime = Field(default_factory=utc_now)
    kif_text: str
    content_hash: str
    match_datetime: datetime | None = None
    players: dict[str, str | None] = Field(default_factory=dict)
    result: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)

    @classmethod
    def from_scrape(
        cls,
        result: SearchResult,
        kif_text: str,
        metadata: dict[str, Any] | None = None,
        job_id: str | None = None,
    ) -> "KifuItem":
        normalized_text = kif_text.strip()
        content_hash = sha256(normalized_text.encode("utf-8")).hexdigest()
        item_id = result.source_game_id or content_hash
        return cls(
            id=item_id,
            username=result.username,
            job_id=job_id,
            source_game_id=result.source_game_id,
            source_game_url=result.detail_url,
            searched_page=result.page,
            kif_text=normalized_text,
            content_hash=content_hash,
            metadata=metadata or {},
            players={
                "sente": _extract_header_value(normalized_text, "先手"),
                "gote": _extract_header_value(normalized_text, "後手"),
            },
            result=_extract_header_value(normalized_text, "結末") or _extract_header_value(normalized_text, "勝者"),
            match_datetime=_extract_datetime(normalized_text),
        )


class KifuItemSummary(BaseModel):
    id: str
    username: str
    job_id: str | None = None
    source_game_id: str
    source_game_url: str
    searched_page: int
    scraped_at: datetime
    match_datetime: datetime | None = None
    players: dict[str, str | None] = Field(default_factory=dict)
    result: str | None = None

    @classmethod
    def from_item(cls, item: KifuItem) -> "KifuItemSummary":
        return cls(
            id=item.id,
            username=item.username,
            job_id=item.job_id,
            source_game_id=item.source_game_id,
            source_game_url=item.source_game_url,
            searched_page=item.searched_page,
            scraped_at=item.scraped_at,
            match_datetime=item.match_datetime,
            players=item.players,
            result=item.result,
        )


def _extract_header_value(text: str, label: str) -> str | None:
    match = re.search(rf"^{re.escape(label)}：(.+)$", text, re.MULTILINE)
    if not match:
        return None
    return match.group(1).strip()


def _extract_datetime(text: str) -> datetime | None:
    match = re.search(r"^開始日時：([0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})$", text, re.MULTILINE)
    if not match:
        return None
    try:
        return datetime.strptime(match.group(1), "%Y/%m/%d %H:%M:%S").replace(tzinfo=timezone.utc)
    except ValueError:
        return None
