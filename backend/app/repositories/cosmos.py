from __future__ import annotations

from typing import Any

from azure.cosmos import CosmosClient, PartitionKey
from azure.cosmos.exceptions import CosmosResourceNotFoundError

from app.config import Settings
from app.models import KifuItem, ScrapeJob, TrackedSource
from app.repositories.base import ScrapeRepository


class CosmosScrapeRepository(ScrapeRepository):
    def __init__(self, settings: Settings) -> None:
        if not settings.cosmos_endpoint or not settings.cosmos_key:
            raise ValueError("Cosmos DB settings are incomplete")
        client = CosmosClient(settings.cosmos_endpoint, credential=settings.cosmos_key)
        database = client.create_database_if_not_exists(id=settings.cosmos_database)
        self._sources = database.create_container_if_not_exists(
            id=settings.cosmos_tracked_sources_container,
            partition_key=PartitionKey(path="/username"),
        )
        self._jobs = database.create_container_if_not_exists(
            id=settings.cosmos_scrape_jobs_container,
            partition_key=PartitionKey(path="/username"),
        )
        self._items = database.create_container_if_not_exists(
            id=settings.cosmos_kifu_items_container,
            partition_key=PartitionKey(path="/username"),
            indexing_policy={
                "indexingMode": "consistent",
                "automatic": True,
                "includedPaths": [
                    {"path": "/username/?"},
                    {"path": "/job_id/?"},
                    {"path": "/source_game_id/?"},
                    {"path": "/source_game_url/?"},
                    {"path": "/match_datetime/?"},
                    {"path": "/scraped_at/?"},
                    {"path": "/content_hash/?"},
                ],
                "excludedPaths": [
                    {"path": "/*"},
                    {"path": "/kif_text/*"},
                    {"path": "/metadata/*"},
                ],
            },
            unique_key_policy={
                "uniqueKeys": [
                    {"paths": ["/source_game_id"]},
                ]
            },
        )

    def upsert_tracked_source(self, source: TrackedSource) -> TrackedSource:
        self._sources.upsert_item(source.model_dump(mode="json"))
        return source

    def get_tracked_source(self, username: str) -> TrackedSource | None:
        query = "SELECT TOP 1 * FROM c WHERE c.username = @username"
        items = list(
            self._sources.query_items(
                query=query,
                parameters=[{"name": "@username", "value": username}],
                partition_key=username,
            )
        )
        return TrackedSource.model_validate(items[0]) if items else None

    def delete_tracked_source(self, username: str) -> bool:
        source = self.get_tracked_source(username)
        if source is None:
            return False
        self._sources.delete_item(item=source.id, partition_key=username)
        return True

    def create_job(self, job: ScrapeJob) -> ScrapeJob:
        self._jobs.create_item(job.model_dump(mode="json"))
        return job

    def update_job(self, job: ScrapeJob) -> ScrapeJob:
        self._jobs.upsert_item(job.model_dump(mode="json"))
        return job

    def get_job(self, job_id: str) -> ScrapeJob | None:
        query = "SELECT TOP 1 * FROM c WHERE c.id = @id"
        items = list(
            self._jobs.query_items(
                query=query,
                parameters=[{"name": "@id", "value": job_id}],
                enable_cross_partition_query=True,
            )
        )
        return ScrapeJob.model_validate(items[0]) if items else None

    def list_jobs(self, username: str | None = None, limit: int = 20) -> list[ScrapeJob]:
        parameters: list[dict[str, Any]] = [{"name": "@limit", "value": limit}]
        query = "SELECT TOP @limit * FROM c"
        query_items_kwargs: dict[str, Any] = {
            "query": query,
            "parameters": parameters,
        }
        if username is not None:
            query += " WHERE c.username = @username"
            parameters.append({"name": "@username", "value": username})
            query_items_kwargs["partition_key"] = username
        else:
            query_items_kwargs["enable_cross_partition_query"] = True
        query += " ORDER BY c.requested_at DESC"
        query_items_kwargs["query"] = query
        items = list(self._jobs.query_items(**query_items_kwargs))
        return [ScrapeJob.model_validate(item) for item in items]

    def list_kifu_items(self, username: str, job_id: str | None = None, limit: int = 20) -> list[KifuItem]:
        parameters: list[dict[str, Any]] = [
            {"name": "@username", "value": username},
            {"name": "@limit", "value": limit},
        ]
        query = "SELECT TOP @limit * FROM c WHERE c.username = @username"
        if job_id is not None:
            query += " AND c.job_id = @job_id"
            parameters.append({"name": "@job_id", "value": job_id})
        query += " ORDER BY c.scraped_at DESC"
        items = list(
            self._items.query_items(
                query=query,
                parameters=parameters,
                partition_key=username,
            )
        )
        return [KifuItem.model_validate(item) for item in items]

    def get_kifu_item(self, username: str, item_id: str) -> KifuItem | None:
        try:
            item = self._items.read_item(item=item_id, partition_key=username)
        except CosmosResourceNotFoundError:
            return None
        return KifuItem.model_validate(item)

    def has_kifu_item(self, username: str, source_game_id: str, content_hash: str | None = None) -> bool:
        query = "SELECT TOP 1 c.id FROM c WHERE c.username = @username AND c.source_game_id = @source_game_id"
        items = list(
            self._items.query_items(
                query=query,
                parameters=[
                    {"name": "@username", "value": username},
                    {"name": "@source_game_id", "value": source_game_id},
                ],
                partition_key=username,
            )
        )
        if items:
            return True
        if not content_hash:
            return False
        hash_query = "SELECT TOP 1 c.id FROM c WHERE c.username = @username AND c.content_hash = @content_hash"
        hash_items = list(
            self._items.query_items(
                query=hash_query,
                parameters=[
                    {"name": "@username", "value": username},
                    {"name": "@content_hash", "value": content_hash},
                ],
                partition_key=username,
            )
        )
        return bool(hash_items)

    def upsert_kifu_item(self, item: KifuItem) -> bool:
        inserted = not self.has_kifu_item(item.username, item.source_game_id, item.content_hash)
        self._items.upsert_item(item.model_dump(mode="json"))
        return inserted
