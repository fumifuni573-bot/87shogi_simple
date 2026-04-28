# Flutter Android 移行 作業手順書

## 目的

既存の SwiftUI / SwiftData ベースの将棋アプリを、同一リポジトリ内に Flutter ベースの Android 対応版として段階移行する。

初期フェーズでは UI の全面移植を急がず、以下を先に固定する。

- Dart 側のドメインモデル
- 将棋ルールロジック
- 時計ロジック
- KIF / CSA パーサ
- 回帰テスト基盤

この順序を守る理由は、UI より先にロジック互換性を固めたほうが、将棋ルールや棋譜互換の回帰を抑えられるため。

## スコープ

### 今回の着手範囲

- Flutter プロジェクトを同一リポジトリに追加
- Riverpod の採用
- Dart 側の `domain` / `logic` / `services` / `test` 骨組み作成
- `DomainModels.swift` の Dart 移植
- `GameEngine.swift` の Dart 移植
- `ClockLogic.swift` の Dart 移植
- `KifuParser.swift` の Dart 移植
- 単体テストとフィクスチャテスト基盤の作成

### 今回は後回しにする範囲

- Flutter UI 全面移植
- ローカル DB 実装
- 広告実装
- 共有 / エクスポート実装
- オンライン対局の実 backend 実装
- 解析エンジン連携

## 参照元

実装時は以下を仕様源として扱う。

- `Models/DomainModels.swift`
- `Logic/GameEngine.swift`
- `Logic/ClockLogic.swift`
- `Services/KifuParser.swift`
- `Stores/GameStore.swift`
- `Persistence/KifuCodec.swift`

## 推奨ディレクトリ構成

リポジトリ直下に Flutter アプリを追加する。

```text
87shogi_simple/
  flutter_app/
    lib/
      app/
      domain/
        models/
      logic/
      services/
      features/
      shared/
    test/
      domain/
      logic/
      services/
      fixtures/
```

## 採用方針

### 状態管理

- Riverpod を採用する
- UI 層の状態とドメインロジックを分離する
- Swift 側の `ObservableObject` 依存は Dart 側へ持ち込まない

### モデル設計

- Dart 側では UI モデルとドメインモデルを分ける
- 将棋ルール判定で使う型は `domain/models` に集約する
- 将来の DB モデルは別レイヤーに分離する

### 検証方針

- Swift 実装を正として振る舞いを揃える
- 盤面、手数、勝敗、千日手、中断、棋譜文言をテストで固定する
- KIF / CSA のサンプルを使った比較テストを先に作る

## 作業手順

### Step 1. Flutter プロジェクトを追加する

目的: Android 側の実装土台を用意する。

作業内容:

1. リポジトリ直下に `flutter_app/` を作成する
2. Flutter アプリを Android 有効の状態で初期化する
3. `lib/` と `test/` の骨組みを上記構成に合わせて整理する
4. 既存 Swift コードは削除せず、仕様参照元として残す

完了条件:

- Flutter アプリが起動できる
- Android ターゲットが有効
- `lib/domain`, `lib/logic`, `lib/services`, `test` が存在する

### Step 2. Riverpod を導入する

目的: 後続の状態管理方式を先に固定する。

作業内容:

1. `flutter_riverpod` を依存に追加する
2. アプリルートを `ProviderScope` で包む
3. 今段階では provider の本実装を増やしすぎず、土台だけ作る

完了条件:

- Riverpod 依存が解決される
- アプリ起動時に `ProviderScope` が有効になっている

### Step 3. DomainModels を Dart に移植する

目的: ゲームロジックとパーサが参照する共通型を先に定義する。

主対象:

- `ShogiPlayer`
- `ShogiPieceType`
- `ShogiPiece`
- `BoardSquare`
- `ShogiGameSnapshot`
- `KifExtendedData`
- `KifVariationBlock`

作業内容:

1. enum と class を Dart へ移植する
2. 盤面、持ち駒、手番、勝敗、棋譜拡張情報の表現を揃える
3. 必要に応じて JSON 変換を用意する
4. Swift 側の UI ネスト型へ依存しない API に整える

完了条件:

- Dart 側だけでゲーム状態を表現できる
- `GameEngine` と `KifuParser` がこのモデルを参照できる

### Step 4. ClockLogic を移植する

目的: 比較的単純な純ロジックから移植を始めて、テスト基盤を先に安定させる。

作業内容:

1. 秒読み、持ち時間減算、表示用の時間整形ロジックを移植する
2. 境界値テストを追加する

完了条件:

- Dart 側の時計計算結果が Swift 側と一致する

### Step 5. GameEngine を移植する

目的: 将棋ルールの中核を Dart へ移す。

重点対象:

- 合法手判定
- 駒の利きと経路判定
- 成り判定
- 持ち駒打ち
- 千日手判定
- 棋譜文言生成
- 終局状態更新

作業内容:

1. 純関数から順に移植する
2. `positionKey` や棋譜表記のような比較しやすい処理から固定する
3. 盤面更新と合法手判定を分けてテスト可能にする
4. `Stores/GameStore.swift` に残る UI 寄り責務は持ち込まない

完了条件:

- Dart のみで 1 手進行と終局判定ができる
- 主要な合法手判定テストが通る

### Step 6. KifuParser を移植する

目的: 既存棋譜資産との互換性を確保する。

対応範囲:

- KIF / CSA 自動判定
- 手合割
- 先手 / 後手ヘッダー
- コメント
- 時間表記
- 変化手順
- 投了 / 詰み / 千日手 / 中断などの終局記号

作業内容:

1. `parse(text, upToMoveCount, includeHistory)` 相当 API を Dart で定義する
2. まず KIF を優先し、その後 CSA を移植する
3. 解析途中の手数停止と軽量パースを維持する
4. 文字コードは UTF-8 以外の要件を別途 PoC 項目として管理する

完了条件:

- KIF の基本ケースを Dart 側で解析できる
- 代表サンプルで最終盤面と結果が一致する

### Step 7. テスト基盤を作る

目的: 以後の移植で仕様が崩れないようにする。

作業内容:

1. `test/domain`, `test/logic`, `test/services` を用意する
2. KIF / CSA フィクスチャを `test/fixtures` に置く
3. 比較観点を以下で固定する

- 最終盤面
- 手数
- 手番
- 勝者
- 勝因
- 千日手 / 中断フラグ
- 棋譜文言

完了条件:

- DomainModels の基本テストがある
- ClockLogic の境界値テストがある
- GameEngine のルールテストがある
- KifuParser のフィクスチャテストがある

## 実装順序の理由

1. DomainModels を先に移すと、GameEngine と KifuParser の依存先が安定する
2. ClockLogic は純粋で小さく、Dart テスト基盤の立ち上げに向く
3. GameEngine は最も重要なロジックで、UI より先に固定する価値が高い
4. KifuParser は外部データ互換の中心なので、UI 実装前に整合性を取る必要がある

## 初回マイルストーン

### Milestone A

- Flutter プロジェクト作成完了
- Riverpod 導入完了
- DomainModels 移植完了
- ClockLogic 移植完了

### Milestone B

- GameEngine の基本合法手判定完了
- KIF パースの基本ケース完了
- 単体テスト実行可能

### Milestone C

- 代表棋譜の比較テストが通る
- Phase 2 着手前の基盤が安定

## レビュー観点

- Swift 側の型やロジックをそのまま機械的に写していないか
- UI 依存が Dart の domain / logic に混入していないか
- 将棋ルールの境界条件がテストされているか
- KIF / CSA の終局記号が正しく復元されるか
- 後続の DB 層追加を妨げる設計になっていないか

## リスクと注意点

### 文字コード

Shift-JIS, EUC-JP, ISO-2022-JP の読み込み要件があるため、Dart 単体で不足があれば早めに PoC を行う。

### ルール回帰

将棋ルールは見落としが起きやすいため、ロジック移植は都度テストで固定する。

### UI 先行の禁止

盤面 UI を先に作るとロジック不整合の検出が遅れるため、このフェーズでは UI を最小限に留める。

## Phase 1 完了条件

以下を満たしたら Phase 1 完了とする。

- Flutter アプリが Android で起動する
- Riverpod が導入されている
- DomainModels, ClockLogic, GameEngine, KifuParser の Dart 実装が存在する
- 最低限の単体テストとフィクスチャテストが通る
- 後続フェーズで UI と DB を追加できる構成になっている

## 次フェーズへの引き継ぎ

Phase 1 完了後は以下へ進む。

1. ローカル DB 層の追加
2. ゲーム状態管理 provider の本実装
3. Flutter 対局 UI の実装
4. 保存一覧、共有、同期、広告の順で機能追加