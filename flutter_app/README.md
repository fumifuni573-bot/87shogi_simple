# flutter_app

87shogi の Flutter フロントエンドです。

## Current persistence model

- 保存棋譜ライブラリは local-first です。取り込んだ KIF とスクレイピング済み棋譜は端末側に保持します。
- backend は現在、将棋ウォーズユーザーの同期実行と KIF detail 取得の source として使います。
- scraped result の UI は `ScrapedKifuCatalog` を経由して読み出します。
- 既定実装は `createDefaultScrapedKifuCatalog()` で選んでいます。server-backed 実装へ移行する場合はこの factory の差し替えを起点にします。

## Main files

- `lib/services/kifu_storage_service.dart`: 保存棋譜ライブラリの local file storage
- `lib/services/shogi_wars_user_store.dart`: 登録ユーザーの local storage
- `lib/services/url_source_store.dart`: 登録 URL の local storage
- `lib/services/scraped_kifu_catalog.dart`: scraped result の永続化境界
- `lib/features/home/saved_kif_list_sheet.dart`: 保存棋譜、登録 URL、登録ユーザー、scraped result の管理 UI

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

## Notes

- Web では保存済み棋譜ライブラリの一部機能が未対応です。
- backend detail を取得できた scraped item だけが local catalog に保存され、再現や保存操作の対象になります。
