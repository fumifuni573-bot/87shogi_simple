from __future__ import annotations

import unittest
from unittest.mock import AsyncMock

from app.config import load_settings
from app.models import JobStatus, ScrapeJobCreate, SearchResult, TrackedSourceCreate
from app.repositories.in_memory import InMemoryScrapeRepository
from app.services.scrape_service import ScrapeService
from app.services.shogi_extend_client import CrawlPage


class ScrapeServiceRunJobTests(unittest.IsolatedAsyncioTestCase):
    username = "chubby_cat"

    def setUp(self) -> None:
        self.repository = InMemoryScrapeRepository()
        self.client = AsyncMock()
        self.service = ScrapeService(
            client=self.client,
            repository=self.repository,
            settings=load_settings(),
        )

    async def test_run_job_succeeds_for_chubby_cat(self) -> None:
        self.service.register_source(TrackedSourceCreate(username=self.username))
        job = self.service.create_job(ScrapeJobCreate(username=self.username, mode="incremental"))

        self.client.discover_max_page.return_value = 2
        self.client.fetch_search_page.side_effect = [
            CrawlPage(
                page=1,
                results=[
                    SearchResult(
                        username=self.username,
                        page=1,
                        detail_url="https://www.shogi-extend.com/swars/battles/chubby_cat-mikyun-20260320_082239",
                        source_game_id="chubby_cat-mikyun-20260320_082239",
                        match_date_label="2026/03/20 08:22:39",
                    )
                ],
                inferred_max_page=2,
            ),
            CrawlPage(page=2, results=[]),
        ]
        self.client.fetch_kif_text.return_value = (
            """開始日時：2026/03/20 08:22:39
先手：chubby_cat
後手：mikyun
結末：先手勝ち
手数----指手---------消費時間--
1 ７六歩(77)   ( 0:01/00:00:01)
""",
            {"battle_key": "chubby_cat-mikyun-20260320_082239"},
        )

        updated_job = await self.service.run_job(job.id)

        self.assertEqual(updated_job.status, JobStatus.succeeded)
        self.assertEqual(updated_job.discovered_max_page, 2)
        self.assertEqual(updated_job.processed_pages, 1)
        self.assertEqual(updated_job.fetched_games, 1)
        self.assertEqual(updated_job.inserted_games, 1)
        self.assertEqual(updated_job.skipped_games, 0)
        self.assertIsNotNone(updated_job.started_at)
        self.assertIsNotNone(updated_job.finished_at)

        saved_source = self.repository.get_tracked_source(self.username)
        self.assertIsNotNone(saved_source)
        self.assertEqual(saved_source.last_successful_page, 1)
        self.assertEqual(saved_source.last_seen_game_id, "chubby_cat-mikyun-20260320_082239")
        self.assertIsNotNone(saved_source.last_scraped_at)

        items = self.repository.list_kifu_items(username=self.username, job_id=job.id, limit=5)
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0].username, self.username)
        self.assertEqual(items[0].job_id, job.id)
        self.assertEqual(items[0].players["sente"], self.username)

    async def test_run_job_marks_failed_for_chubby_cat_when_kif_fetch_fails(self) -> None:
        self.service.register_source(TrackedSourceCreate(username=self.username))
        job = self.service.create_job(ScrapeJobCreate(username=self.username, mode="incremental"))

        self.client.discover_max_page.return_value = 1
        self.client.fetch_search_page.return_value = CrawlPage(
            page=1,
            results=[
                SearchResult(
                    username=self.username,
                    page=1,
                    detail_url="https://www.shogi-extend.com/swars/battles/chubby_cat-mikyun-20260320_082239",
                    source_game_id="chubby_cat-mikyun-20260320_082239",
                    match_date_label="2026/03/20 08:22:39",
                )
            ],
            inferred_max_page=1,
        )
        self.client.fetch_kif_text.side_effect = ValueError("KIF fetch failed for chubby_cat")

        with self.assertRaisesRegex(ValueError, "KIF fetch failed for chubby_cat"):
            await self.service.run_job(job.id)

        failed_job = self.repository.get_job(job.id)
        self.assertIsNotNone(failed_job)
        self.assertEqual(failed_job.status, JobStatus.failed)
        self.assertEqual(failed_job.error_summary, "KIF fetch failed for chubby_cat")
        self.assertIsNotNone(failed_job.finished_at)

        items = self.repository.list_kifu_items(username=self.username, job_id=job.id, limit=5)
        self.assertEqual(items, [])


if __name__ == "__main__":
    unittest.main()