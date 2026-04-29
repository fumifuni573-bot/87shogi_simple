from __future__ import annotations

import asyncio
import unittest
from unittest.mock import AsyncMock

from app.config import load_settings
from app.services.shogi_extend_client import ShogiExtendClient


class _FakeResponse:
    def __init__(self, *, text: str = "", payload: object | None = None) -> None:
        self.text = text
        self._payload = payload

    def raise_for_status(self) -> None:
        return None

    def json(self) -> object:
        return self._payload


class ShogiExtendClientSearchPayloadTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = ShogiExtendClient(load_settings())

    def tearDown(self) -> None:
        # The tests only exercise pure parsing helpers, so the async client is never opened on the network.
        asyncio.run(self.client._client.aclose())

    def test_extract_search_results_from_w_json_payload(self) -> None:
        payload = {
            "query": "chubby_cat",
            "page": 1,
            "per": 10,
            "total": 23,
            "records": [
                {
                    "key": "yanagi47136-chubby_cat-20260429_151051",
                    "show_path": "/w/yanagi47136-chubby_cat-20260429_151051",
                    "battled_at": "2026-04-29T15:10:51.000+09:00",
                },
                {
                    "key": "chubby_cat-Pona6Nov-20260429_124859",
                    "show_path": "/w/chubby_cat-Pona6Nov-20260429_124859",
                    "battled_at": "2026-04-29T12:48:59.000+09:00",
                },
            ],
        }

        results = self.client._extract_search_results_from_payload(
            username="chubby_cat",
            page=1,
            payload=payload,
        )

        self.assertEqual(len(results), 2)
        self.assertEqual(
            results[0].detail_url,
            "https://www.shogi-extend.com/swars/battles/yanagi47136-chubby_cat-20260429_151051",
        )
        self.assertEqual(results[0].source_game_id, "yanagi47136-chubby_cat-20260429_151051")
        self.assertEqual(results[0].match_date_label, "2026-04-29T15:10:51.000+09:00")
        self.assertEqual(
            self.client._extract_max_page_from_payload(payload),
            3,
        )


class ShogiExtendClientFallbackTests(unittest.IsolatedAsyncioTestCase):
        async def asyncSetUp(self) -> None:
                self.client = ShogiExtendClient(load_settings())

        async def asyncTearDown(self) -> None:
                await self.client.close()

        async def test_fetch_search_page_falls_back_to_html_when_w_json_has_no_records(self) -> None:
                html = """
<!doctype html>
<html>
    <body>
        <div>
            <a href="/swars/battles/chubby_cat-mikyun-20260320_082239/?viewpoint=black">詳細</a>
            <span>3/20 08:22</span>
        </div>
        <nav>
            <a href="/swars/search?query=chubby_cat&page=1">1</a>
            <a href="/swars/search?query=chubby_cat&page=8">8</a>
        </nav>
    </body>
</html>
"""
                self.client._client.get = AsyncMock(
                        side_effect=[
                                _FakeResponse(payload={"query": "chubby_cat", "records": []}),
                                _FakeResponse(text=html),
                        ]
                )

                page = await self.client.fetch_search_page("chubby_cat", 1)

                self.assertEqual(len(page.results), 1)
                self.assertEqual(page.results[0].source_game_id, "chubby_cat-mikyun-20260320_082239")
                self.assertEqual(
                        page.results[0].detail_url,
                        "https://www.shogi-extend.com/swars/battles/chubby_cat-mikyun-20260320_082239/?viewpoint=black",
                )
                self.assertEqual(page.inferred_max_page, 8)
                self.assertEqual(self.client._client.get.await_count, 2)


if __name__ == "__main__":
    unittest.main()