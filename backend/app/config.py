from __future__ import annotations

from dataclasses import dataclass
import os


@dataclass(frozen=True)
class Settings:
    base_url: str
    user_agent: str
    request_timeout_seconds: float
    known_streak_stop_count: int
    cosmos_endpoint: str | None
    cosmos_key: str | None
    cosmos_database: str
    cosmos_tracked_sources_container: str
    cosmos_scrape_jobs_container: str
    cosmos_kifu_items_container: str

    @property
    def has_cosmos(self) -> bool:
        return bool(self.cosmos_endpoint and self.cosmos_key)


def load_settings() -> Settings:
    return Settings(
        base_url=os.getenv("SCRAPER_BASE_URL", "https://www.shogi-extend.com").rstrip("/"),
        user_agent=os.getenv("SCRAPER_USER_AGENT", "87shogi-simple-bot/0.1"),
        request_timeout_seconds=float(os.getenv("SCRAPER_REQUEST_TIMEOUT_SECONDS", "20")),
        known_streak_stop_count=int(os.getenv("SCRAPER_KNOWN_STREAK_STOP_COUNT", "10")),
        cosmos_endpoint=os.getenv("COSMOS_ENDPOINT"),
        cosmos_key=os.getenv("COSMOS_KEY"),
        cosmos_database=os.getenv("COSMOS_DATABASE", "shogi_extend"),
        cosmos_tracked_sources_container=os.getenv("COSMOS_TRACKED_SOURCES_CONTAINER", "tracked_sources"),
        cosmos_scrape_jobs_container=os.getenv("COSMOS_SCRAPE_JOBS_CONTAINER", "scrape_jobs"),
        cosmos_kifu_items_container=os.getenv("COSMOS_KIFU_ITEMS_CONTAINER", "kifu_items"),
    )
