# 読み込み最適化ロードマップ

## 🔴 **即実装レベル（1～2日で完結）**

### 1. **ファイル一覧スキャン（reloadSavedKifFiles）の最適化**
**現状問題:**
- 各ファイルに対して `decodePersistedRecord(from: text)` → フル復号を実行
- 実は "タイトル・手数・結果" だけが必要で、詳細な局面データは不要
- `decodePersistedRecord` は KifuCodec.decode（失敗時 KifuParser.parse）で重い

**改善案:**
- ファイル一覧表示用に専用の軽量パース関数 `parseKifuHeader(from:)` を作る
- ヘッダーとフッターだけを抽出（いまの `KifuCodec.parseMetadata` の拡張版）
- `decodePersistedRecord` を呼ばずに直接 `parseMetadata` → `SavedKifFile` 構築

**効果:**
- ファイル数 × (フル復号時間 - ヘッダー解析時間) の短縮
- 一覧表示時の UI レスポンス大幅改善
- 100手の棋譜なら 80～90% 削減の可能性

---

### 2. **レビュー局面キャッシュサイズの制限**
**現状問題:**
- `reviewSnapshotCache: [Int: GameSnapshot]` は制限なく増殖
- 500手の棋譜なら 500 個の GameSnapshot がメモリに残る
- endReviewMode でクリアするまで解放されない

**改善案:**
- キャッシュサイズ上限を設定（例：最大 20 局面）
- 訪問順に LRU (Least Recently Used) で古い局面を削除
- 同時に `reviewSourceText` が存在すれば、キャッシュミス時に再生成可能

**実装:**
```swift
private var reviewSnapshotCache: [Int: GameSnapshot] = [:]
private let reviewCacheMaxSize = 20

func snapshotForReview(at index: Int) -> GameSnapshot? {
    // ... 既存キャッシュ取得 ...
    
    // キャッシュに追加するとき
    if reviewSnapshotCache.count >= reviewCacheMaxSize {
        // 最も古いキー（index の最小値など）を削除
        let oldestKey = reviewSnapshotCache.keys.min() ?? index - reviewCacheMaxSize
        reviewSnapshotCache.removeValue(forKey: oldestKey)
    }
    reviewSnapshotCache[normalizedIndex] = snapshot
}
```

**効果:**
- メモリ使用量を固定化（制限以内）
- 小手数の棋譜では影響ゼロ
- 大手数の棋譜でも確定的な上限を維持

---

### 3. **savedKifFiles の遅延整列**
**現状問題:**
- `reloadSavedKifFiles()` 内で毎回 `sorted(by:)` を実行
- リロードのたびに O(n log n) の計算

**改善案:**
- `@State` で整列状態を管理（昇順/降順フラグ）
- リロード時は unsorted で返す
- UIの表示側で `.sorted()` モディファイアを使うか、初回のみソート
- 再度の追加/削除は一覧の前後に挿入（O(n) 回避可能）

**効果:**
- リロード頻度が多い場合は顕著（特に URL 一括同期時）
- 実装は簡単で、副作用も少ない

---

## 🟡 **中期改善レベル（1～2週間、提案段階）**

### 4. **DB キャッシュ層の導入**
**現状問題:**
- `reloadSavedKifFiles()` で毎回全レコードを fetchAll()
- メモリ上に持つほうが速いが、更新との同期が課題

**改善案:**
- `@State private var dbRecordCache: [UUID: PersistedShogiGameRecord]?` を用意
- 初回の fetchAll() 結果をキャッシュ
- 追加/削除時のみ差分更新
- キャッシュ無効化は明示的に（保存成功時など）

**効果:**
- DB クエリの削減（特に多数のレコード存在時）
- リロード呼び出しが多い場合の改善

---

### 5. **URL ネットワーク取得の並列化**
**現状問題:**
- 複数の登録 URL を順番に fetchText() → fetchAndSave()
- ネットワーク遅延が逐次的に積み重なる

**改善案:**
- `SyncService.fetchAndSaveAll()` を async/await TaskGroup で並列化
- 同時タスク数を制限（例：3～5 個）
- 各タスクのエラーはキャッチして個別ログ

**効果:**
- 複数 URL 同期時の時間が大幅短縮（10 URL なら 10÷3 ≈ 3.3 倍）
- バッテリー/ネットワーク負荷のバランス考慮

---

### 6. **KifuParser の部分パース最適化**
**現状問題:**
- `upToMoveCount` で指定局面以降の手は実行していないはずが、内部では全ヘッダー・全手を走査？
- 確認が必要（実装をコード確認）

**改善案:**
- ヘッダー抽出後、指定手数到達時にループを抜ける
- 残りのテキストはスキップ（ビットも読まない）

**効果:**
- 大手数の棋譜で、後ろの方の局面を見るとき高速化
- ただし実装複雑度が増す

---

## 🟢 **将来展望（1ヶ月以上、アーキテクチャ級）**

### 7. **KIF テキスト圧縮保存**
- gzip/zlib 圧縮してデータベースに保存
- ネットワーク転送・DB サイズ削減
- 解凍はバックグラウンドで

### 8. **レビュー履歴の完全遅延化**
- `moveHistory` そのものを廃止（読み込み時）
- `reviewSourceText` から都度パース
- ライブゲームは従来通り（現在の `moveHistory`）

### 9. **インデックス KIF** (カスタムバイナリ形式)
- 盤面遷移を事前コンパイルしたバイナリフォーマット
- KIF テキストはメタデータのみ保持
- ローカルファイル化で超高速レビュー

---

## 📊 **優先度・ROI 比較表**

| 項目 | 実装時間 | 効果度 | ROI | 推奨 |
|-----|--------|------|-----|-----|
| 1. ファイル一覧ヘッダー最適化 | 2h | ⭐⭐⭐⭐ | 非常に高 | **✅ 次実装** |
| 2. キャッシュサイズ制限 | 1.5h | ⭐⭐⭐ | 高 | **✅ 次実装** |
| 3. 遅延整列 | 1h | ⭐⭐ | 中 | ✅ その次 |
| 4. DB キャッシュ層 | 3h | ⭐⭐ | 中 | 中期 |
| 5. URL 並列化 | 2h | ⭐⭐⭐ | 高 | 中期 |
| 6. 部分パース最適化 | 2h | ⭐⭐ | 低～中 | 要確認 |
| 7～9. 抜本改革 | 2週+ | ⭐⭐⭐⭐⭐ | 超高 | 将来 |

---

## 🎯 **推奨実装順序**

### Phase 1 (今週)
1. **ファイル一覧スキャン最適化** → 一覧表示の体感改善が目視できる
2. **キャッシュサイズ制限** → メモリ安定化、リスク低い

### Phase 2 (来週)
3. **遅延整列** → すぐ入る、小物
4. **URL 並列化** → 登録URL同期が速くなる実感

### Phase 3 (2週目以降)
5. DB キャッシュ、部分パース確認、将来展望検討

---

## 🔍 **実装前の確認項目**

- [ ] `KifuParser.parse(text:, upToMoveCount:)` の内部で本当に途中で終了しているか確認
- [ ] `reviewSnapshotCache` の実際のサイズ（500手棋譜でどれくらい？）
- [ ] `reloadSavedKifFiles()` の呼び出し頻度と所要時間を計測
- [ ] プロファイラでボトルネック確認（CPU/Memory）
