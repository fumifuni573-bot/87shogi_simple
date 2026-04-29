# Shogi Extend Scraper Backend

将棋ウォーズの username を起点に `shogi-extend` を巡回し、各対局の KIF を Cosmos DB に保存するバックエンドです。

## Current scope

- username の登録
- full / incremental ジョブの起動
- ページ上限の探索
- 検索結果から対局 URL の抽出
- 対局詳細ページから KIF を回収するフォールバック付き抽出
- Cosmos DB への upsert 保存

## Directory

```text
backend/
  app/
    main.py
    config.py
    models.py
    repositories/
    services/
```

## Environment variables

```text
SCRAPER_BASE_URL=https://www.shogi-extend.com
SCRAPER_USER_AGENT=87shogi-simple-bot/0.1
COSMOS_ENDPOINT=
COSMOS_KEY=
COSMOS_DATABASE=shogi_extend
COSMOS_TRACKED_SOURCES_CONTAINER=tracked_sources
COSMOS_SCRAPE_JOBS_CONTAINER=scrape_jobs
COSMOS_KIFU_ITEMS_CONTAINER=kifu_items
```

Cosmos DB の接続情報が未設定の場合は in-memory repository で起動します。

## Run

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --app-dir backend
```

## API

- `GET /health`
- `POST /tracked-sources`
- `GET /tracked-sources/{username}`
- `POST /scrape-jobs`
- `GET /scrape-jobs/{job_id}`

## Notes

- `kifu_items` container は `/username` partition key を想定します。
- `kif_text` は RU 削減のため index から除外しています。
- KIF 取得は確認済みの内部エンドポイント `/w/{battle_key}.kif` を第一優先で使い、補助メタデータは `/w/{battle_key}.json` から取得します。
- 対局詳細ページの HTML 解析はフォールバックとして残しています。
