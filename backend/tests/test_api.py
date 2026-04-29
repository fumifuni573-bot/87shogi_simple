from __future__ import annotations

import unittest
from unittest.mock import AsyncMock

from fastapi.testclient import TestClient

from app.main import app
from app.models import KifuItem, SearchResult


class BackendApiTests(unittest.TestCase):
    username = "chubby_cat"

    def setUp(self) -> None:
        self._client_context = TestClient(app)
        self.client = self._client_context.__enter__()

    def tearDown(self) -> None:
        self._client_context.__exit__(None, None, None)

    def test_tracked_source_crud_for_chubby_cat(self) -> None:
        create_response = self.client.post(
            "/tracked-sources",
            json={"username": self.username, "enabled": True},
        )

        self.assertEqual(create_response.status_code, 200)
        self.assertEqual(create_response.json()["username"], self.username)

        get_response = self.client.get(f"/tracked-sources/{self.username}")
        self.assertEqual(get_response.status_code, 200)
        self.assertEqual(get_response.json()["site"], "shogi_extend_swars")

        delete_response = self.client.delete(f"/tracked-sources/{self.username}")
        self.assertEqual(delete_response.status_code, 200)
        self.assertEqual(delete_response.json(), {"deleted": True})

        missing_response = self.client.get(f"/tracked-sources/{self.username}")
        self.assertEqual(missing_response.status_code, 404)

    def test_create_and_list_scrape_jobs_for_chubby_cat(self) -> None:
        service = app.state.service
        original_run_job = service.run_job
        service.run_job = AsyncMock(return_value=None)
        self.addCleanup(setattr, service, "run_job", original_run_job)

        create_response = self.client.post(
            "/scrape-jobs",
            json={"username": self.username, "mode": "incremental"},
        )

        self.assertEqual(create_response.status_code, 200)
        payload = create_response.json()
        self.assertEqual(payload["username"], self.username)
        self.assertEqual(payload["mode"], "incremental")
        self.assertEqual(payload["status"], "queued")
        self.assertGreaterEqual(service.run_job.await_count, 1)

        list_response = self.client.get(f"/scrape-jobs?username={self.username}&limit=5")
        self.assertEqual(list_response.status_code, 200)

        jobs = list_response.json()
        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0]["id"], payload["id"])
        self.assertEqual(jobs[0]["username"], self.username)

    def test_list_kifu_items_for_chubby_cat_and_job_filter(self) -> None:
        repository = app.state.repository
        item = KifuItem.from_scrape(
            SearchResult(
                username=self.username,
                page=8,
                detail_url="https://www.shogi-extend.com/swars/battles/chubby_cat-mikyun-20260320_082239",
                source_game_id="chubby_cat-mikyun-20260320_082239",
                match_date_label="2026/03/20 08:22:39",
            ),
            """開始日時：2026/03/20 08:22:39
先手：chubby_cat
後手：mikyun
結末：先手勝ち
手数----指手---------消費時間--
1 ７六歩(77)   ( 0:01/00:00:01)
""",
            metadata={"source": "test"},
            job_id="job-chubby-cat-1",
        )
        inserted = repository.upsert_kifu_item(item)
        self.assertTrue(inserted)

        response = self.client.get(
            "/kifu-items",
            params={"username": self.username, "job_id": "job-chubby-cat-1", "limit": 5},
        )

        self.assertEqual(response.status_code, 200)
        items = response.json()
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["username"], self.username)
        self.assertEqual(items[0]["job_id"], "job-chubby-cat-1")
        self.assertEqual(items[0]["source_game_id"], "chubby_cat-mikyun-20260320_082239")
        self.assertEqual(items[0]["players"]["sente"], self.username)

    def test_get_kifu_item_detail_for_chubby_cat(self) -> None:
        repository = app.state.repository
        item = KifuItem.from_scrape(
            SearchResult(
                username=self.username,
                page=8,
                detail_url="https://www.shogi-extend.com/swars/battles/chubby_cat-mikyun-20260320_082239",
                source_game_id="chubby_cat-mikyun-20260320_082239",
                match_date_label="2026/03/20 08:22:39",
            ),
            """開始日時：2026/03/20 08:22:39
先手：chubby_cat
後手：mikyun
結末：先手勝ち
手数----指手---------消費時間--
1 ７六歩(77)   ( 0:01/00:00:01)
""",
            metadata={"source": "test", "battle_key": "chubby_cat-mikyun-20260320_082239"},
            job_id="job-chubby-cat-1",
        )
        repository.upsert_kifu_item(item)

        response = self.client.get(f"/kifu-items/{item.id}", params={"username": self.username})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["id"], item.id)
        self.assertEqual(payload["username"], self.username)
        self.assertEqual(payload["kif_text"], item.kif_text)
        self.assertEqual(payload["metadata"]["battle_key"], "chubby_cat-mikyun-20260320_082239")

    def test_get_kifu_item_detail_returns_404_when_missing(self) -> None:
        response = self.client.get("/kifu-items/missing-item", params={"username": self.username})

        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["detail"], "kifu item not found")


if __name__ == "__main__":
    unittest.main()