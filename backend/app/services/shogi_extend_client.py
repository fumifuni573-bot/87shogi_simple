from __future__ import annotations

from dataclasses import dataclass
from html import unescape
import json
import math
import re
from urllib.parse import parse_qs, urlencode, urljoin, urlparse

from bs4 import BeautifulSoup
import httpx

from app.config import Settings
from app.models import SearchResult


@dataclass(slots=True)
class CrawlPage:
    page: int
    results: list[SearchResult]
    inferred_max_page: int | None = None


class ShogiExtendClient:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client = httpx.AsyncClient(
            headers={"User-Agent": settings.user_agent},
            timeout=settings.request_timeout_seconds,
            follow_redirects=True,
        )

    async def close(self) -> None:
        await self._client.aclose()

    def build_search_url(self, username: str, page: int) -> str:
        query = urlencode({"query": username, "page": page})
        return f"{self._settings.base_url}/swars/search?{query}"

    def build_search_json_url(self) -> str:
        return f"{self._settings.base_url}/w.json"

    async def fetch_search_page(self, username: str, page: int) -> CrawlPage:
        json_response = await self._client.get(
            self.build_search_json_url(),
            params={"query": username, "page": page, "per": 10},
        )
        json_response.raise_for_status()
        payload = json_response.json()
        results = self._extract_search_results_from_payload(username=username, page=page, payload=payload)
        inferred_max_page = self._extract_max_page_from_payload(payload)
        if results or inferred_max_page is not None:
            return CrawlPage(page=page, results=results, inferred_max_page=inferred_max_page)

        response = await self._client.get(self.build_search_url(username, page))
        response.raise_for_status()
        html = response.text
        results = self._extract_search_results(username=username, page=page, html=html)
        inferred_max_page = self._extract_max_page(html)
        return CrawlPage(page=page, results=results, inferred_max_page=inferred_max_page)

    async def discover_max_page(self, username: str) -> int:
        first_page = await self.fetch_search_page(username, 1)
        if first_page.inferred_max_page:
            return first_page.inferred_max_page
        if not first_page.results:
            return 1

        lower = 1
        upper = 2
        while True:
            candidate = await self.fetch_search_page(username, upper)
            if candidate.inferred_max_page:
                return candidate.inferred_max_page
            if not candidate.results:
                break
            lower = upper
            upper *= 2

        while lower + 1 < upper:
            midpoint = (lower + upper) // 2
            candidate = await self.fetch_search_page(username, midpoint)
            if candidate.results:
                lower = midpoint
            else:
                upper = midpoint
        return lower

    async def fetch_kif_text(self, detail_url: str) -> tuple[str, dict[str, str]]:
        battle_key = self._extract_battle_key(detail_url)
        metadata: dict[str, str] = {"detail_url": detail_url, "battle_key": battle_key}

        direct_kif_url = f"{self._settings.base_url}/w/{battle_key}.kif"
        direct_kif_response = await self._client.get(direct_kif_url)
        direct_kif_response.raise_for_status()
        direct_kif_text = self._normalize_kif(direct_kif_response.text)
        if "手数----指手" in direct_kif_text:
            metadata["kif_url"] = str(direct_kif_response.url)
            json_url = f"{self._settings.base_url}/w/{battle_key}.json"
            json_response = await self._client.get(json_url)
            if json_response.is_success:
                metadata.update(self._extract_json_metadata(json_response.text, str(json_response.url)))
            return direct_kif_text, metadata

        response = await self._client.get(detail_url)
        response.raise_for_status()
        html = response.text
        soup = BeautifulSoup(html, "html.parser")

        detail_link = soup.find(string=re.compile(r"詳細URL："))
        if detail_link:
            metadata["detail_marker"] = str(detail_link)

        button = soup.select_one("button.KifCopyButton")
        if button:
            for attr_name in ("data-kif", "data-clipboard-text", "data-copy-text"):
                attr_value = button.get(attr_name)
                if attr_value:
                    return self._normalize_kif(attr_value), metadata

        script_kif = self._extract_kif_from_scripts(html)
        if script_kif:
            return self._normalize_kif(script_kif), metadata

        pre = soup.find("pre")
        if pre and "手数----指手" in pre.get_text("\n"):
            return self._normalize_kif(pre.get_text("\n")), metadata

        raise ValueError(f"KIF text was not found for {detail_url}")

    def _extract_search_results(self, username: str, page: int, html: str) -> list[SearchResult]:
        soup = BeautifulSoup(html, "html.parser")
        results: list[SearchResult] = []
        seen_urls: set[str] = set()

        for anchor in soup.find_all("a", href=True):
            href = urljoin(self._settings.base_url, anchor["href"])
            if "/swars/battles/" not in href:
                continue
            if href.endswith("/kento") or href.endswith("/piyo_shogi"):
                continue
            if href in seen_urls:
                continue
            seen_urls.add(href)
            game_id = self._extract_game_id(href)
            row_text = anchor.find_parent().get_text(" ", strip=True) if anchor.find_parent() else anchor.get_text(" ", strip=True)
            results.append(
                SearchResult(
                    username=username,
                    page=page,
                    detail_url=href,
                    source_game_id=game_id,
                    match_date_label=self._extract_match_date(row_text),
                )
            )

        return results

    def _extract_search_results_from_payload(self, username: str, page: int, payload: object) -> list[SearchResult]:
        if not isinstance(payload, dict):
            return []

        raw_records = payload.get("records")
        if not isinstance(raw_records, list):
            return []

        results: list[SearchResult] = []
        for record in raw_records:
            if not isinstance(record, dict):
                continue
            detail_url = self._build_detail_url_from_record(record)
            if detail_url is None:
                continue
            source_game_id = self._extract_game_id(detail_url)
            if not source_game_id:
                continue
            match_date_label = None
            battled_at = record.get("battled_at")
            if isinstance(battled_at, str) and battled_at:
                match_date_label = battled_at
            results.append(
                SearchResult(
                    username=username,
                    page=page,
                    detail_url=detail_url,
                    source_game_id=source_game_id,
                    match_date_label=match_date_label,
                )
            )
        return results

    def _extract_max_page_from_payload(self, payload: object) -> int | None:
        if not isinstance(payload, dict):
            return None
        total = payload.get("total")
        per = payload.get("per")
        if not isinstance(total, int) or total < 0:
            return None
        if not isinstance(per, int) or per <= 0:
            return None
        return max(1, math.ceil(total / per))

    def _build_detail_url_from_record(self, record: dict[str, object]) -> str | None:
        key = record.get("key")
        if isinstance(key, str) and key:
            return f"{self._settings.base_url}/swars/battles/{key}"
        show_path = record.get("show_path")
        if isinstance(show_path, str) and show_path:
            return urljoin(self._settings.base_url, show_path)
        return None

    def _extract_max_page(self, html: str) -> int | None:
        soup = BeautifulSoup(html, "html.parser")
        page_numbers: list[int] = []
        for anchor in soup.find_all("a", href=True):
            href = anchor["href"]
            parsed = urlparse(urljoin(self._settings.base_url, href))
            if not parsed.path.endswith("/swars/search"):
                continue
            page_values = parse_qs(parsed.query).get("page")
            if not page_values:
                continue
            try:
                page_numbers.append(int(page_values[0]))
            except ValueError:
                continue
        return max(page_numbers) if page_numbers else None

    def _extract_game_id(self, detail_url: str) -> str:
        path = urlparse(detail_url).path.rstrip("/")
        return path.split("/")[-1]

    def _extract_battle_key(self, detail_url: str) -> str:
        path = urlparse(detail_url).path.rstrip("/")
        parts = [part for part in path.split("/") if part]
        if "battles" not in parts:
            return parts[-1]
        battle_index = parts.index("battles")
        if battle_index + 1 >= len(parts):
            raise ValueError(f"Unexpected detail URL format: {detail_url}")
        return parts[battle_index + 1]

    def _extract_match_date(self, row_text: str) -> str | None:
        match = re.search(r"([0-9]{1,2}/[0-9]{1,2})", row_text)
        if not match:
            return None
        return match.group(1)

    def _extract_kif_from_scripts(self, html: str) -> str | None:
        patterns = [
            r"clipboard\.writeText\((?P<quote>['\"])(?P<content>.*?)(?P=quote)\)",
            r"copyToClipboard\((?P<quote>['\"])(?P<content>.*?)(?P=quote)\)",
            r'"kif"\s*:\s*(?P<quote>"|")(?P<content>.*?)(?P=quote)',
        ]
        for pattern in patterns:
            match = re.search(pattern, html, re.DOTALL)
            if not match:
                continue
            return self._decode_script_string(match.group("content"))

        json_match = re.search(r"<script[^>]*type=\"application/json\"[^>]*>(?P<content>.*?)</script>", html, re.DOTALL)
        if json_match:
            try:
                payload = json.loads(json_match.group("content"))
            except json.JSONDecodeError:
                payload = None
            if isinstance(payload, dict):
                kif_value = payload.get("kif")
                if isinstance(kif_value, str):
                    return kif_value
        return None

    def _extract_json_metadata(self, json_text: str, json_url: str) -> dict[str, str]:
        metadata: dict[str, str] = {"json_url": json_url}
        try:
            payload = json.loads(json_text)
        except json.JSONDecodeError:
            return metadata

        if not isinstance(payload, dict):
            return metadata

        for key in ("id", "key", "critical_turn", "outbreak_turn", "turn_max"):
            value = payload.get(key)
            if value is not None:
                metadata[key] = str(value)

        battled_at = payload.get("battled_at")
        if isinstance(battled_at, str):
            metadata["battled_at"] = battled_at

        final_info = payload.get("final_info")
        if isinstance(final_info, dict):
            final_name = final_info.get("name")
            if isinstance(final_name, str):
                metadata["final_name"] = final_name

        return metadata

    def _decode_script_string(self, value: str) -> str:
        decoded = bytes(value, "utf-8").decode("unicode_escape")
        return unescape(decoded)

    def _normalize_kif(self, kif_text: str) -> str:
        return kif_text.replace("\r\n", "\n").replace("\\n", "\n").strip()
