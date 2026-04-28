//
//  ContentView.swift
//  87吹棋
//
//  Created by Tomoki kakihana on 2026/03/22.
//

import SwiftUI
import Combine
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// 画面全体のUIと状態管理を行うメインビュー
struct ContentView: View {
    /// 駒落ち設定の種類
    enum GameHandicap: String, CaseIterable, Identifiable {
        case none = "平手"
        case lance = "香落ち"
        case bishop = "角落ち"
        case rook = "飛車落ち"
        case twoPieces = "二枚落ち"
        case fourPieces = "四枚落ち"
        case sixPieces = "六枚落ち"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .none: return "通常の初期配置で開始します"
            case .lance: return "駒落ち側（先手）の香車を1枚落として開始します"
            case .bishop: return "駒落ち側（先手）の角行を落として開始します"
            case .rook: return "駒落ち側（先手）の飛車を落として開始します"
            case .twoPieces: return "駒落ち側（先手）の飛車・角行を落として開始します"
            case .fourPieces: return "駒落ち側（先手）の飛車・角行・香車2枚を落として開始します"
            case .sixPieces: return "駒落ち側（先手）の飛車・角行・香車2枚・桂馬2枚を落として開始します"
            }
        }
    }

    /// Domain層の型（外部モデル）への互換エイリアス
    typealias Player = ShogiPlayer
    typealias PieceType = ShogiPieceType
    typealias Piece = ShogiPiece
    typealias Square = BoardSquare
    typealias PendingPromotionMove = PromotionPendingMove
    typealias GameSnapshot = ShogiGameSnapshot
    typealias PersistedGameRecord = PersistedShogiGameRecord
    typealias SavedKifFile = SavedKifFileModel
    typealias RegisteredKifuSource = RegisteredKifuSourceModel

    private enum KifuViewerEntry {
        case savedFile(SavedKifFile)
        case registeredSource(RegisteredKifuSource)
    }

    /// SwiftData ModelContext（KifuRepository に渡す）
    @Environment(\.modelContext) private var modelContext
    /// 対局状態の管理（盤面・手番など）
    @StateObject private var gameStore = GameStore()
    /// 持ち時間・タイマーの管理
    @StateObject private var clockStore = ClockStore()
    /// URL登録ソースの一括同期サービス
    @StateObject private var syncService = SyncService()
    /// バックグラウンドDB操作アクター（初回onAppearで生成）
    @State private var backgroundKifuActor: BackgroundKifuActor? = nil
    @State private var savedKifFiles: [SavedKifFile] = []
    @State private var registeredKifuSources: [RegisteredKifuSource] = []
    @State private var savedKifReloadTask: Task<Void, Never>? = nil
    @State private var showSavedKifSheet = false
    @State private var showURLRegistrationSheet = false
    @State private var showGameSetupSheet = false
    @State private var showTimerScreen = false
    @State private var showTimerSettingsSheet = false
    @State private var timerSettingsDetent: PresentationDetent = .fraction(0.42)
    @State private var showHomeExitConfirm = false
    @State private var homeExitFromReviewMode = false
    @State private var isRematchSetupFlow = false
    @State private var showResignConfirm = false
    @State private var resignTargetPlayer: Player?
    @State private var showRenameKifAlert = false
    @State private var renameTitleInput = ""
    @State private var renameTargetFile: SavedKifFile?
    @State private var isSavingKif = false
    @State private var reviewFinalSnapshot: GameSnapshot? = nil
    @State private var reviewSourceText: String? = nil
    @State private var reviewSnapshotCache: [Int: GameSnapshot] = [:]
    @State private var reviewLoadedMoveCount: Int = 0
    @State private var byoYomiAlertPulse = false
    @State private var exportKifShareItem: KifExportShareItem?
    @State private var lastExportedKifTempURL: URL?
    @State private var matchInitialSeconds: TimeInterval = 600
    @State private var matchByoYomiSeconds: Int = 0
    @State private var standaloneSenteInitialSeconds: TimeInterval = 600
    @State private var standaloneGoteInitialSeconds: TimeInterval = 600
    @State private var standaloneByoYomiSeconds: Int = 0
    @State private var didInitializeTimeProfiles = false
    @AppStorage("savedKifFolderAssignmentsV1") private var savedKifFolderAssignmentsRaw = "{}"
    /// 終局ポップアップを何らかのボタンで操作済みかどうか（次のリセットまで持続）
    @State private var isGameEndHandled = false
    /// 終局ポップアップが一度でも表示されたかどうか（フラッシュ防止用）
    @State private var hasShownGameEndPopup = false
    private let minimumCellSize: CGFloat = 30
    private let isRunningInPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    /// KIF棋譜のData Layer（SwiftData永続化）
    private var repository: KifuRepository { KifuRepository(context: modelContext) }

    /// 盤面のフレーム情報を子Viewから親Viewへ伝播するためのPreferenceKey
    private struct BoardFrameAnchorKey: PreferenceKey {
        static var defaultValue: Anchor<CGRect>? = nil
        static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
            value = value ?? nextValue()
        }
    }

    private struct SavedKifDBSnapshot: Sendable {
        let id: UUID
        let title: String
        let createdAt: Date
        let resultSummary: String
        let moveCount: Int
        let sourceURL: String?
        let folderName: String
    }

    /// 対局モード=青、検討モード=緑でテーマカラーを切り替える
    private var themeColor: Color { isReviewMode ? Palette.review : Palette.info }

    // ClockStore経由でタイマー・持ち時間関連の値を取得するプロパティ
    /// 先手の初期持ち時間（秒）
    private var senteInitialSeconds: TimeInterval {
        get { clockStore.senteInitialSeconds }
        nonmutating set { clockStore.senteInitialSeconds = newValue }
    }
    /// 後手の初期持ち時間（秒）
    private var goteInitialSeconds: TimeInterval {
        get { clockStore.goteInitialSeconds }
        nonmutating set { clockStore.goteInitialSeconds = newValue }
    }
    /// 先手の残り持ち時間（秒）
    private var senteClockRemaining: TimeInterval {
        get { clockStore.senteClockRemaining }
        nonmutating set { clockStore.senteClockRemaining = newValue }
    }
    /// 後手の残り持ち時間（秒）
    private var goteClockRemaining: TimeInterval {
        get { clockStore.goteClockRemaining }
        nonmutating set { clockStore.goteClockRemaining = newValue }
    }
    /// 秒読み設定（秒）
    private var byoYomiSeconds: Int {
        get { clockStore.byoYomiSeconds }
        nonmutating set { clockStore.byoYomiSeconds = newValue }
    }
    /// 先手の残り秒読み（秒）
    private var senteByoYomiRemaining: TimeInterval {
        get { clockStore.senteByoYomiRemaining }
        nonmutating set { clockStore.senteByoYomiRemaining = newValue }
    }
    /// 後手の残り秒読み（秒）
    private var goteByoYomiRemaining: TimeInterval {
        get { clockStore.goteByoYomiRemaining }
        nonmutating set { clockStore.goteByoYomiRemaining = newValue }
    }
    /// 現在タイマーが動作中のプレイヤー
    private var timerActivePlayer: Player? {
        get { clockStore.timerActivePlayer }
        nonmutating set { clockStore.timerActivePlayer = newValue }
    }
    /// タイマーが動作中かどうか
    private var isTimerRunning: Bool {
        get { clockStore.isTimerRunning }
        nonmutating set { clockStore.isTimerRunning = newValue }
    }
    /// 持ち時間切れになったプレイヤー
    private var timerExpiredPlayer: Player? {
        get { clockStore.timerExpiredPlayer }
        nonmutating set { clockStore.timerExpiredPlayer = newValue }
    }
    /// タイマーの最終更新時刻
    private var timerLastUpdate: Date {
        get { clockStore.timerLastUpdate }
        nonmutating set { clockStore.timerLastUpdate = newValue }
    }
    /// タイマー表示の回転状態
    private var timerRotationQuarterTurns: Int {
        get { clockStore.timerRotationQuarterTurns }
        nonmutating set { clockStore.timerRotationQuarterTurns = newValue }
    }

    /// 勝者（決着時のみセット）
    private var winner: Player? {
        get { gameStore.winner }
        nonmutating set { gameStore.winner = newValue }
    }

    /// 現在の手番
    private var turn: Player {
        get { gameStore.turn }
        nonmutating set { gameStore.turn = newValue }
    }

    /// 勝敗理由（詰み・投了など）
    private var winReason: String {
        get { gameStore.winReason }
        nonmutating set { gameStore.winReason = newValue }
    }

    /// 千日手かどうか
    private var isSennichite: Bool {
        get { gameStore.isSennichite }
        nonmutating set { gameStore.isSennichite = newValue }
    }

    /// 対局中断かどうか
    private var isInterrupted: Bool {
        get { gameStore.isInterrupted }
        nonmutating set { gameStore.isInterrupted = newValue }
    }

    /// 画面下部の案内メッセージ
    private var statusMessage: String {
        get { gameStore.statusMessage }
        nonmutating set { gameStore.statusMessage = newValue }
    }

    /// スタート画面の表示状態
    private var showStartScreen: Bool {
        get { gameStore.showStartScreen }
        nonmutating set { gameStore.showStartScreen = newValue }
    }

    /// 対局終了ポップアップの表示状態
    private var showGameEndPopup: Bool {
        get { gameStore.showGameEndPopup }
        nonmutating set { gameStore.showGameEndPopup = newValue }
    }

    /// 検討モードかどうか
    private var isReviewMode: Bool {
        get { gameStore.isReviewMode }
        nonmutating set { gameStore.isReviewMode = newValue }
    }

    /// 対局開始演出の表示状態
    private var showMatchStartCue: Bool {
        get { gameStore.showMatchStartCue }
        nonmutating set { gameStore.showMatchStartCue = newValue }
    }

    /// 選択中のマス（またはnil）
    private var selected: Square? {
        get { gameStore.selected }
        nonmutating set { gameStore.selected = newValue }
    }

    /// 選択中の持ち駒種別（またはnil）
    private var selectedDropType: PieceType? {
        get { gameStore.selectedDropType }
        nonmutating set { gameStore.selectedDropType = newValue }
    }

    /// 成り選択待ちの移動情報
    private var pendingPromotionMove: PendingPromotionMove? {
        get { gameStore.pendingPromotionMove }
        nonmutating set { gameStore.pendingPromotionMove = newValue }
    }

    /// 検討モード時の現在の手数
    private var reviewIndex: Int {
        get { gameStore.reviewIndex }
        nonmutating set { gameStore.reviewIndex = newValue }
    }

    /// 千日手判定用の局面ハッシュ出現回数
    private var positionCounts: [String: Int] {
        get { gameStore.positionCounts }
        nonmutating set { gameStore.positionCounts = newValue }
    }

    /// 手順ごとの盤面スナップショット履歴
    private var moveHistory: [GameSnapshot] {
        get { gameStore.moveHistory }
        nonmutating set { gameStore.moveHistory = newValue }
    }

    /// 棋譜（KIF形式文字列配列）
    private var moveRecords: [String] {
        get { gameStore.moveRecords }
        nonmutating set { gameStore.moveRecords = newValue }
    }

    /// 盤面の状態（9x9の2次元配列）
    private var board: [[Piece?]] {
        get { gameStore.board }
        nonmutating set { gameStore.board = newValue }
    }

    /// 先手の持ち駒
    private var senteHand: [PieceType: Int] {
        get { gameStore.senteHand }
        nonmutating set { gameStore.senteHand = newValue }
    }

    /// 後手の持ち駒
    private var goteHand: [PieceType: Int] {
        get { gameStore.goteHand }
        nonmutating set { gameStore.goteHand = newValue }
    }

    /// 対局終了ポップアップを抑制するか
    private var suppressGameEndPopup: Bool {
        get { gameStore.suppressGameEndPopup }
        nonmutating set { gameStore.suppressGameEndPopup = newValue }
    }

    /// 振り駒演出の表示状態
    private var showFurigomaCue: Bool {
        get { gameStore.showFurigomaCue }
        nonmutating set { gameStore.showFurigomaCue = newValue }
    }

    /// 振り駒の表裏結果
    private var furigomaResults: [Bool] {
        get { gameStore.furigomaResults }
        nonmutating set { gameStore.furigomaResults = newValue }
    }

    /// 振り駒の公開枚数
    private var furigomaRevealCount: Int {
        get { gameStore.furigomaRevealCount }
        nonmutating set { gameStore.furigomaRevealCount = newValue }
    }

    /// 振り駒ルーレットのアニメーション用カウンタ
    private var furigomaRouletteTick: Int {
        get { gameStore.furigomaRouletteTick }
        nonmutating set { gameStore.furigomaRouletteTick = newValue }
    }

    /// 振り駒の結果メッセージ
    private var furigomaResultMessage: String {
        get { gameStore.furigomaResultMessage }
        nonmutating set { gameStore.furigomaResultMessage = newValue }
    }

    /// 現在選択中の駒落ち設定
    private var selectedHandicap: GameHandicap {
        get { gameStore.selectedHandicap }
        nonmutating set { gameStore.selectedHandicap = newValue }
    }

    /// 盤面アニメーション用カウンタ
    private var boardMotionTick: Int {
        get { gameStore.boardMotionTick }
        nonmutating set { gameStore.boardMotionTick = newValue }
    }

    /// ツールバーの先頭配置（OSごとに切り替え）
    private var leadingToolbarPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .navigation
        #else
        .topBarLeading
        #endif
    }

    /// ツールバーの末尾配置（OSごとに切り替え）
    private var trailingToolbarPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }

    /// メイン画面のView構築
    /// メイン画面のView構築（レイアウト分岐・各種オーバーレイ・アラート・シート表示）
    var body: some View {
        GeometryReader { proxy in // 画面サイズに応じてレイアウトを調整
            let metrics = layoutMetrics(for: proxy.size)

            Group { // スタート画面 or 対局画面の分岐
                if showStartScreen { // スタート画面
                    ZStack { // スタート画面の重ね合わせ（タイマー画面遷移含む）
                        if !showTimerScreen {
                            startScreenView
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        }
                        if showTimerScreen {
                            timerScreenView
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                        }
                    }
                } else { // 対局画面
                    Group { // 画面幅・向きに応じたレイアウト分岐
                        if metrics.isWide {
                            wideLayout(cellSize: metrics.cellSize, size: proxy.size)
                        } else if metrics.isPhoneLandscape {
                            phoneLandscapeLayout(cellSize: metrics.cellSize, size: proxy.size)
                        } else {
                            compactLayout(cellSize: metrics.cellSize, size: proxy.size)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            // 画面左上にホーム・棋譜ボタンを重ねて表示
            .overlay(alignment: .topLeading) {
                if !showStartScreen {
                    HStack(spacing: 8) {
                        homeButton
                        if isReviewMode {
                            kifIconButton
                        }
                    }
                    .padding(.top, 2)
                    .padding(.leading, 8 + proxy.safeAreaInsets.leading)
                }
            }
        }
        // 背景グラデーション（検討モードで色変更）
        .background(
            ZStack {
                LinearGradient(
                    colors: isReviewMode
                        ? [Color(red: 1.00, green: 1.00, blue: 1.00), Color(red: 0.98, green: 0.98, blue: 0.99)]
                        : [Palette.bgTop, Palette.bgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                if !showStartScreen {
                    SakuraPetalBackgroundView()
                        .opacity(isReviewMode ? 0.22 : 0.28)
                }
            }
            .ignoresSafeArea()
        )
        // モード切替時のアニメーション
        .animation(.easeInOut(duration: 0.4), value: isReviewMode)
        .animation(.easeInOut(duration: 0.28), value: showTimerScreen)
        .safeAreaInset(edge: .bottom) {
            if !showStartScreen {
                BannerAdContainerView(adUnitID: AdConfig.bannerAdUnitID)
            }
        }
        // 画面表示時の初期化処理
        .onAppear {
            initializeIndependentTimeProfilesIfNeeded()
            registerCurrentPositionIfNeeded()
            if !byoYomiAlertPulse {
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    byoYomiAlertPulse = true
                }
            }
            // バックグラウンドDB操作アクターを生成（modelContainerが確定してから）
            if backgroundKifuActor == nil {
                backgroundKifuActor = BackgroundKifuActor(modelContainer: modelContext.container)
            }
            if !isRunningInPreviews {
                // 旧ファイルベース棋譜 → SwiftData へ移行（初回起動）
                repository.migrateFromFileStoreIfNeeded(isRunningInPreviews: isRunningInPreviews)
                reloadSavedKifFiles()
                reloadRegisteredKifuSources()
            }
            updateIdleTimerDisabledState()
        }
        // 画面非表示時の後処理（iOS: 省電力復帰）
        .onDisappear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
        // 勝敗決定時の処理
        .onChange(of: winner) {
            if winner != nil {
                isTimerRunning = false
            }
            if !suppressGameEndPopup, !isReviewMode, winner != nil {
                presentGameEndPopupSmoothly()
            }
        }
        // 千日手成立時の処理
        .onChange(of: isSennichite) {
            if isSennichite {
                isTimerRunning = false
            }
            if !suppressGameEndPopup, !isReviewMode, isSennichite {
                presentGameEndPopupSmoothly()
            }
        }
        // 中断時の処理
        .onChange(of: isInterrupted) {
            if isInterrupted {
                isTimerRunning = false
            }
            if !suppressGameEndPopup, !isReviewMode, isInterrupted {
                presentGameEndPopupSmoothly()
            }
        }
        // 手番変更時のタイマー・秒読み初期化
        .onChange(of: turn) {
            if !showStartScreen, !isReviewMode, isTimerRunning {
                timerActivePlayer = turn
                prepareByoYomiForTurnStart(turn)
                timerLastUpdate = Date()
            }
        }
        // タイマー開始/停止時の省電力設定
        .onChange(of: isTimerRunning) {
            updateIdleTimerDisabledState()
        }
        // タイマー画面表示切替時の省電力設定
        .onChange(of: showTimerScreen) {
            updateIdleTimerDisabledState()
        }
        // スタート画面表示切替時の省電力設定
        .onChange(of: showStartScreen) {
            updateIdleTimerDisabledState()
        }
        // 1秒ごとのタイマーTick処理
        .onReceive(clockStore.timerTicker) { now in
            handleTimerTick(now)
        }
        // Share Extension / ディープリンクからのURL受け取り
        .onOpenURL { incomingURL in
            handleIncomingSharedURL(incomingURL)
        }
        // 棋譜一覧シート
        .sheet(isPresented: $showSavedKifSheet) {
            savedKifListView
        }
        .kifExportShareSheet(item: $exportKifShareItem) {
            cleanupExportedKifTempFile()
        }
        // URL登録シート
        .sheet(isPresented: $showURLRegistrationSheet) {
            urlRegistrationSheetView
        }
        // 対局設定シート
        .sheet(isPresented: $showGameSetupSheet) {
            gameSetupView
        }
        // タイマー設定シート
        .sheet(isPresented: $showTimerSettingsSheet) {
            timerSettingsSheetView
        }
        // 成り選択アラート
        .alert("成りますか？", isPresented: Binding(
            get: { pendingPromotionMove != nil },
            set: { show in
                if !show { pendingPromotionMove = nil }
            }
        )) {
            Button("成る") {
                if let move = pendingPromotionMove {
                    executeMove(from: move.from, to: move.to, promote: true)
                    pendingPromotionMove = nil
                }
            }
            Button("成らない") {
                if let move = pendingPromotionMove {
                    executeMove(from: move.from, to: move.to, promote: false)
                    pendingPromotionMove = nil
                }
            }
            Button("戻る", role: .cancel) {
                pendingPromotionMove = nil
                statusMessage = "成り選択をキャンセルしました。別の手を選べます"
            }
        } message: {
            Text("この駒は成ることができます")
        }
        // 投了確認アラート
        .alert("投了しますか？", isPresented: $showResignConfirm) {
            Button("投了する", role: .destructive) {
                if let player = resignTargetPlayer {
                    resign(player: player)
                }
                resignTargetPlayer = nil
            }
            Button("キャンセル", role: .cancel) {
                resignTargetPlayer = nil
            }
        } message: {
            Text("この対局を投了します。よろしいですか？")
        }
        // 対局終了オーバーレイ
        .overlay {
            if showGameEndPopup {
                gameEndOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        // 盤面フレーム情報をMatchStartOverlayViewへ伝播
        .overlayPreferenceValue(BoardFrameAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if (showMatchStartCue || showFurigomaCue), let anchor {
                    let boardRect = proxy[anchor]
                    MatchStartOverlayView(
                        showFurigomaCue: showFurigomaCue,
                        showMatchStartCue: showMatchStartCue,
                        boardRect: boardRect,
                        furigomaResults: furigomaResults,
                        furigomaRevealCount: furigomaRevealCount,
                        furigomaRouletteTick: furigomaRouletteTick,
                        matchStartTopRole: matchStartTopRole,
                        matchStartBottomRole: matchStartBottomRole
                    )
                }
            }
        }
        // 振り駒・開始演出・終了演出のアニメーション
        .animation(.easeInOut(duration: 0.2), value: showFurigomaCue)
        .animation(.easeInOut(duration: 0.2), value: showMatchStartCue)
        .animation(.easeInOut(duration: 0.22), value: showGameEndPopup)
    }

    /// 対局終了ポップアップをスムーズに表示
    private func presentGameEndPopupSmoothly() {
        guard !showGameEndPopup else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard !suppressGameEndPopup,
                  !isReviewMode,
                  winner != nil || isSennichite || isInterrupted else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                showGameEndPopup = true
                hasShownGameEndPopup = true
            }
        }
    }

    /// 対局開始演出の上側ラベル
    private var matchStartTopRole: String {
        (selectedHandicap == .none && turn == .gote) ? "先手" : "後手"
    }

    /// 対局開始演出の下側ラベル
    private var matchStartBottomRole: String {
        matchStartTopRole == "先手" ? "後手" : "先手"
    }

    /// 対局終了時のメッセージ
    private var gameEndMessage: String {
        if let winner {
            return "\(winner.label)の勝ち（\(winReason)）"
        }
        if isSennichite {
            return "千日手（引き分け）"
        }
        if isInterrupted {
            return "対局中断"
        }
        return ""
    }

    /// 対局終了時のタイトル
    private var gameEndTitle: String {
        if let winner {
            return winner == .sente ? "先手勝利" : "後手勝利"
        }
        if isSennichite { return "引き分け" }
        if isInterrupted { return "対局中断" }
        return "対局終了"
    }

    /// 対局終了タイトルの色
    private var gameEndTitleColor: Color {
        if winner != nil {
            return themeColor
        }
        return Palette.neutral
    }

    /// 対局終了時のサブタイトル（未使用）
    private var gameEndSubtitle: String {
        return ""
    }

    /// 対局終了時のオーバーレイView
    private var gameEndOverlay: some View {
        GameEndOverlayView(
            title: gameEndTitle,
            subtitle: gameEndSubtitle,
            titleColor: gameEndTitleColor,
            tint: Palette.info,
            onReview: {
                enterReviewModeFromOverlay()
            },
            onSaveKif: {
                saveFinishedGameFromOverlay()
            },
            onExportKif: {
                prepareKifExport()
            },
            onRematch: {
                isRematchSetupFlow = true
                isGameEndHandled = true
                showGameEndPopup = false
                showGameSetupSheet = true
            },
            onHome: {
                isGameEndHandled = true
                showGameEndPopup = false
                showStartScreen = true
            }
        )
    }

    private func saveFinishedGameFromOverlay() {
        isGameEndHandled = true
        showGameEndPopup = false

        DispatchQueue.main.async {
            saveCurrentRecordToLibrary()
        }
    }

    /// スタート画面の View（StartScreenView.swift に分離）
    private var startScreenView: some View {
        StartScreenView(
            onStartGame: { showGameSetupSheet = true },
            onOpenKifu: { openSavedKifSheet() },
            onOpenURLRegistration: { showURLRegistrationSheet = true },
            onOpenTimer: { openTimerScreen() }
        )
    }

    private var timerScreenView: some View {
        GeometryReader { proxy in
            // アイコン行(52) + バナー(54) + 余白を確保しつつ、中央領域を最小化してパネルを最大化
            let centerControlHeight = max(120, proxy.size.height * 0.165)
            let panelSlotHeight = max(160, (proxy.size.height - centerControlHeight - 24) / 2)
            let panelSide = max(140, min(proxy.size.width - 10, panelSlotHeight))

            VStack(spacing: 8) {
                timerClockPanel(for: .gote, isTopPanel: true)
                    .frame(width: panelSide, height: panelSide)
                    .frame(maxWidth: .infinity)

                timerCenterIconControls
                    .frame(height: centerControlHeight)

                timerClockPanel(for: .sente, isTopPanel: false)
                    .frame(width: panelSide, height: panelSide)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var timerCenterIconControls: some View {
        TimerCenterControlsView(
            accent: Palette.info,
            isDisabled: isTimerRunning,
            onHome: { closeTimerScreen() },
            onReset: { resetTimerClocks() },
            onSettings: { openTimerSettingsSheet() },
            onRotate: { timerRotationQuarterTurns = (timerRotationQuarterTurns + 1) % 4 }
        )
    }

    private var timerSettingsSheetView: some View {
        NavigationStack {
            GeometryReader { proxy in
                let isWide = proxy.size.width > 560

                ScrollView {
                    Group {
                        if isWide {
                            HStack(alignment: .top, spacing: 6) {
                                timerSettingSection(for: .gote)
                                timerSettingSection(for: .sente)
                            }
                        } else {
                            VStack(spacing: 6) {
                                timerSettingSection(for: .gote)
                                timerSettingSection(for: .sente)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
            .toolbar {
                ToolbarItem(placement: leadingToolbarPlacement) {
                    Button("閉じる") {
                        showTimerSettingsSheet = false
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.42), .medium, .large], selection: $timerSettingsDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private func timerSettingSection(for player: Player) -> some View {
        TimerSettingCardView(
            playerName: timerPlayerName(for: player),
            currentMinutes: currentTimerMinutes(for: player),
            timerMinuteOptions: timerMinuteOptions,
            timerMinuteLabel: timerMinuteLabel,
            onPickerChange: { setTimerMinutes(for: player, minutes: $0) },
            onAdjust: { adjustTimerMinutes(for: player, delta: $0) }
        )
    }

    private func timerClockPanel(for player: Player, isTopPanel: Bool) -> some View {
        TimerClockPanelView(
            playerName: timerPlayerName(for: player),
            remaining: displayTimerSeconds(for: player),
            isActive: timerActivePlayer == player,
            hasExpired: timerExpiredPlayer == player,
            isTopPanel: isTopPanel,
            rotationQuarterTurns: timerRotationQuarterTurns,
            onTap: { handleTimerTap(player) },
            onLongPress: { pauseTimerByLongPress() }
        )
    }

    private var timerStatusText: String {
        if let expired = timerExpiredPlayer {
            return "\(timerPlayerName(for: expired))の時間切れ"
        }
        if let active = timerActivePlayer, isTimerRunning {
            return "\(timerPlayerName(for: active))の持ち時間"
        }
        if let active = timerActivePlayer {
            return "停止中（\(timerPlayerName(for: active))の手番）"
        }
        return "開始ボタンまたは手番側をタップ"
    }

    private func timerPlayerName(for player: Player) -> String {
        player == .sente ? "Player 1" : "Player 2"
    }

    private func openTimerScreen() {
        applyStandaloneTimeSettingsToLiveClock()
        withAnimation(.easeInOut(duration: 0.28)) {
            showTimerScreen = true
        }
        timerLastUpdate = Date()
        timerSettingsDetent = .fraction(0.42)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if showStartScreen && showTimerScreen {
                showTimerSettingsSheet = true
            }
        }
    }

    private func openTimerSettingsSheet() {
        isTimerRunning = false
        timerLastUpdate = Date()
        timerSettingsDetent = .fraction(0.42)
        showTimerSettingsSheet = true
    }

    private func closeTimerScreen() {
        isTimerRunning = false
        timerLastUpdate = Date()
        withAnimation(.easeInOut(duration: 0.28)) {
            showTimerScreen = false
        }
    }

    private func currentTimerMinutes(for player: Player) -> Int {
        let seconds = player == .sente ? standaloneSenteInitialSeconds : standaloneGoteInitialSeconds
        return min(60, max(0, Int((seconds / 60).rounded())))
    }

    private func setTimerMinutes(for player: Player, minutes: Int) {
        let clampedMinutes = min(60, max(0, minutes))
        let value = TimeInterval(clampedMinutes * 60)
        if player == .sente {
            standaloneSenteInitialSeconds = value
        } else {
            standaloneGoteInitialSeconds = value
        }
        if showStartScreen && showTimerScreen {
            applyStandaloneTimeSettingsToLiveClock()
        }
    }

    private func currentMatchTimerMinutes() -> Int {
        min(60, max(0, Int((matchInitialSeconds / 60).rounded())))
    }

    private func setMatchSharedTimerMinutes(_ minutes: Int) {
        let clampedMinutes = min(60, max(0, minutes))
        let value = TimeInterval(clampedMinutes * 60)
        matchInitialSeconds = value
    }

    private func adjustTimerMinutes(for player: Player, delta: Int) {
        setTimerMinutes(for: player, minutes: currentTimerMinutes(for: player) + delta)
    }

    private var timerMinuteOptions: [Int] {
        [0, 1, 3, 5, 10] + Array(stride(from: 15, through: 60, by: 5))
    }

    private func nearestTimerMinuteOption(to minutes: Int) -> Int {
        let clamped = min(60, max(0, minutes))
        return timerMinuteOptions.min(by: { abs($0 - clamped) < abs($1 - clamped) }) ?? 5
    }

    private func timerMinuteLabel(_ minute: Int) -> String {
        minute == 0 ? "なし" : "\(minute)分"
    }

    private var isUnlimitedMatchTimeSetting: Bool {
        matchInitialSeconds <= 0 && matchByoYomiSeconds <= 0
    }

    private var isUnlimitedTimeSetting: Bool {
        senteInitialSeconds <= 0 && goteInitialSeconds <= 0 && byoYomiSeconds <= 0
    }

    private var byoYomiSecondOptions: [Int] {
        [0, 10, 20, 30, 60]
    }

    private func setMatchByoYomiSeconds(_ seconds: Int) {
        matchByoYomiSeconds = max(0, seconds)
    }

    private func initializeIndependentTimeProfilesIfNeeded() {
        guard !didInitializeTimeProfiles else { return }
        let initial = max(senteInitialSeconds, goteInitialSeconds)
        matchInitialSeconds = initial
        matchByoYomiSeconds = byoYomiSeconds
        standaloneSenteInitialSeconds = senteInitialSeconds
        standaloneGoteInitialSeconds = goteInitialSeconds
        standaloneByoYomiSeconds = byoYomiSeconds
        didInitializeTimeProfiles = true
    }

    private func applyStandaloneTimeSettingsToLiveClock() {
        senteInitialSeconds = standaloneSenteInitialSeconds
        goteInitialSeconds = standaloneGoteInitialSeconds
        byoYomiSeconds = standaloneByoYomiSeconds
        resetTimerClocks()
    }

    private func applyMatchTimeSettingsToLiveClock() {
        senteInitialSeconds = matchInitialSeconds
        goteInitialSeconds = matchInitialSeconds
        byoYomiSeconds = matchByoYomiSeconds
        resetTimerClocks()
    }

    private func displayTimerSeconds(for player: Player) -> TimeInterval {
        let main = player == .sente ? senteClockRemaining : goteClockRemaining
        let byo = player == .sente ? senteByoYomiRemaining : goteByoYomiRemaining
        return ClockLogic.displaySeconds(main: main, byoYomiRemaining: byo, byoYomiSeconds: byoYomiSeconds)
    }

    private func prepareByoYomiForTurnStart(_ player: Player) {
        let main = player == .sente ? senteClockRemaining : goteClockRemaining
        guard let prepared = ClockLogic.preparedByoYomiRemaining(main: main, byoYomiSeconds: byoYomiSeconds) else { return }

        if player == .sente {
            senteByoYomiRemaining = prepared
        } else {
            goteByoYomiRemaining = prepared
        }
    }

    private func consumeByoYomi(player: Player, elapsed: TimeInterval) -> Bool {
        if player == .sente {
            let result = ClockLogic.consumeByoYomi(
                currentRemaining: senteByoYomiRemaining,
                byoYomiSeconds: byoYomiSeconds,
                elapsed: elapsed
            )
            senteByoYomiRemaining = result.remaining
            return result.alive
        } else {
            let result = ClockLogic.consumeByoYomi(
                currentRemaining: goteByoYomiRemaining,
                byoYomiSeconds: byoYomiSeconds,
                elapsed: elapsed
            )
            goteByoYomiRemaining = result.remaining
            return result.alive
        }
    }

    private func resetTimerClocks() {
        isTimerRunning = false
        timerActivePlayer = nil
        timerExpiredPlayer = nil
        timerLastUpdate = Date()
        senteClockRemaining = senteInitialSeconds
        goteClockRemaining = goteInitialSeconds
        let byo = TimeInterval(byoYomiSeconds)
        senteByoYomiRemaining = byo
        goteByoYomiRemaining = byo
    }

    private func toggleTimerRunning() {
        if isTimerRunning {
            isTimerRunning = false
            timerLastUpdate = Date()
            return
        }

        if timerExpiredPlayer != nil {
            return
        }

        if timerActivePlayer == nil {
            timerActivePlayer = .sente
            prepareByoYomiForTurnStart(.sente)
        }
        timerLastUpdate = Date()
        isTimerRunning = true
    }

    private func pauseTimerByLongPress() {
        guard isTimerRunning else { return }
        isTimerRunning = false
        timerLastUpdate = Date()
    }

    private func updateIdleTimerDisabledState() {
        #if canImport(UIKit)
        let shouldDisable = showStartScreen && showTimerScreen && isTimerRunning
        UIApplication.shared.isIdleTimerDisabled = shouldDisable
        #endif
    }

    private func handleTimerTap(_ player: Player) {
        if timerExpiredPlayer != nil {
            return
        }

        if !isTimerRunning {
            // 実機タイマー同様、押した側ではなく相手側の時計を開始する
            timerActivePlayer = player.opposite
            prepareByoYomiForTurnStart(player.opposite)
            timerLastUpdate = Date()
            isTimerRunning = true
            return
        }

        guard timerActivePlayer == player else { return }
        timerActivePlayer = player.opposite
        prepareByoYomiForTurnStart(player.opposite)
        timerLastUpdate = Date()
    }

    private func handleTimerTick(_ now: Date) {
        let isTimerScreenActive = showStartScreen && showTimerScreen
        let isMatchScreenActive = !showStartScreen && !isReviewMode && !isGameOver()
        guard isTimerScreenActive || isMatchScreenActive else {
            timerLastUpdate = now
            return
        }
        guard isTimerRunning, let active = timerActivePlayer else {
            timerLastUpdate = now
            return
        }

        let elapsed = max(0, now.timeIntervalSince(timerLastUpdate))
        timerLastUpdate = now
        guard elapsed > 0 else { return }

        if active == .sente {
            var remainder = elapsed
            if senteClockRemaining > 0 {
                let consumeMain = min(senteClockRemaining, remainder)
                senteClockRemaining -= consumeMain
                remainder -= consumeMain
            }

            if remainder > 0 || senteClockRemaining <= 0 {
                let alive = consumeByoYomi(player: .sente, elapsed: remainder)
                if !alive {
                    senteClockRemaining = 0
                    senteByoYomiRemaining = 0
                    handleTimerExpired(loser: .sente)
                }
            }
        } else {
            var remainder = elapsed
            if goteClockRemaining > 0 {
                let consumeMain = min(goteClockRemaining, remainder)
                goteClockRemaining -= consumeMain
                remainder -= consumeMain
            }

            if remainder > 0 || goteClockRemaining <= 0 {
                let alive = consumeByoYomi(player: .gote, elapsed: remainder)
                if !alive {
                    goteClockRemaining = 0
                    goteByoYomiRemaining = 0
                    handleTimerExpired(loser: .gote)
                }
            }
        }
    }

    private func handleTimerExpired(loser: Player) {
        timerExpiredPlayer = loser
        timerActivePlayer = nil
        isTimerRunning = false

        // 対局モードでは既存の終局ポップアップ（winner 監視）を利用する
        if !showStartScreen, !isReviewMode, !isGameOver() {
            winner = loser.opposite
            winReason = "時間切れ"
            statusMessage = "\(loser.label)の時間切れ。\(loser.opposite.label)の勝ちです"
        }
    }

    private func formattedTimer(_ seconds: TimeInterval) -> String {
        let wholeSeconds = Int(max(0, seconds).rounded(.down))
        let minutes = wholeSeconds / 60
        let sec = wholeSeconds % 60
        return String(format: "%02d:%02d", minutes, sec)
    }

    private func startMatchModeTimer() {
        isTimerRunning = true
        timerExpiredPlayer = nil
        timerActivePlayer = turn
        prepareByoYomiForTurnStart(turn)
        timerLastUpdate = Date()
    }

    private func startMatchFromSetup(handicap: GameHandicap) {
        isRematchSetupFlow = false
        applyMatchTimeSettingsToLiveClock()
        showGameSetupSheet = false
        showStartScreen = false
        showMatchStartCue = false
        showFurigomaCue = false

        isTimerRunning = false
        timerActivePlayer = nil
        timerExpiredPlayer = nil
        timerLastUpdate = Date()

        if MatchStartLogic.shouldUseFurigoma(handicap: handicap) {
            resetGame(handicap: handicap, initialTurn: .sente, announceStatus: false)
            startFurigomaThenBeginMatch(handicap: handicap)
        } else {
            beginMatchAfterOpeningTurn(
                handicap: handicap,
                openingTurn: MatchStartLogic.defaultOpeningTurn(handicap: handicap),
                furigomaSummary: nil
            )
        }
    }

    private func startFurigomaThenBeginMatch(handicap: GameHandicap) {
        showMatchStartCue = false
        furigomaResults = MatchStartLogic.randomFurigomaResults()
        furigomaRevealCount = 0
        furigomaRouletteTick = 0
        furigomaResultMessage = ""

        withAnimation(.easeInOut(duration: 0.2)) {
            showFurigomaCue = true
        }

        startFurigomaRouletteAnimation()

        for idx in furigomaResults.indices {
            let delay = MatchStartLogic.revealDelay(at: idx)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard showFurigomaCue else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
                    furigomaRevealCount = idx + 1
                }
            }
        }

        let revealFinishedDelay = MatchStartLogic.revealFinishedDelay(pieceCount: furigomaResults.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + revealFinishedDelay) {
            guard showFurigomaCue else { return }

            let openingTurn = MatchStartLogic.openingTurn(from: furigomaResults)
            furigomaResultMessage = openingTurn == .sente ? "" : "上側が先手"

            let summary = MatchStartLogic.furigomaSummary(results: furigomaResults)
            DispatchQueue.main.asyncAfter(deadline: .now() + MatchStartLogic.furigomaResultHold) {
                guard !showStartScreen, !isReviewMode else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFurigomaCue = false
                }
                beginMatchAfterOpeningTurn(handicap: handicap, openingTurn: openingTurn, furigomaSummary: summary)
            }
        }
    }

    private func startFurigomaRouletteAnimation() {
        let interval = MatchStartLogic.furigomaSpinInterval
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            guard showFurigomaCue else { return }
            withAnimation(.linear(duration: interval)) {
                furigomaRouletteTick += 1
            }
            if furigomaRevealCount < furigomaResults.count {
                startFurigomaRouletteAnimation()
            }
        }
    }

    private func beginMatchAfterOpeningTurn(handicap: GameHandicap, openingTurn: Player, furigomaSummary: String?) {
        resetGame(handicap: handicap, initialTurn: openingTurn, announceStatus: false)

        showMatchStartCue = true
        DispatchQueue.main.asyncAfter(deadline: .now() + MatchStartLogic.matchStartCueDuration) {
            if !showStartScreen && !isReviewMode {
                showMatchStartCue = false
                if isUnlimitedMatchTimeSetting {
                    isTimerRunning = false
                    timerActivePlayer = nil
                    timerExpiredPlayer = nil
                    timerLastUpdate = Date()
                    if let furigomaSummary {
                        statusMessage = "\(furigomaSummary)で\(openingTurn.label)先手。制限時間なしで対局開始"
                    } else {
                        statusMessage = "制限時間なしで対局開始"
                    }
                } else {
                    startMatchModeTimer()
                    if let furigomaSummary {
                        statusMessage = "\(furigomaSummary)で\(openingTurn.label)先手で対局開始"
                    }
                }
            }
        }
    }

    private var gameSetupView: some View {
        GameSetupSheetView(
            selectedHandicap: Binding(
                get: { selectedHandicap },
                set: { selectedHandicap = $0 }
            ),
            sharedTimerMinutes: Binding(
                get: { nearestTimerMinuteOption(to: currentMatchTimerMinutes()) },
                set: { setMatchSharedTimerMinutes($0) }
            ),
            byoYomiSeconds: Binding(
                get: { matchByoYomiSeconds },
                set: { setMatchByoYomiSeconds($0) }
            ),
            timerMinuteOptions: timerMinuteOptions,
            timerMinuteLabel: timerMinuteLabel,
            byoYomiSecondOptions: byoYomiSecondOptions,
            handicapDescription: selectedHandicap.description,
            cardBackground: Palette.cardBg.opacity(0.7),
            accentTint: Palette.info,
            onAppearSyncSharedMinutes: {
                setMatchSharedTimerMinutes(nearestTimerMinuteOption(to: currentMatchTimerMinutes()))
            },
            onStart: {
                startMatchFromSetup(handicap: selectedHandicap)
            },
            onCancel: {
                closeGameSetupSheet()
            },
            onClose: {
                closeGameSetupSheet()
            }
        )
    }

    private func closeGameSetupSheet() {
        showGameSetupSheet = false

        guard isRematchSetupFlow,
              !showStartScreen,
              !isReviewMode,
              isGameOver() else {
            isRematchSetupFlow = false
            return
        }

        isGameEndHandled = false
        withAnimation(.easeInOut(duration: 0.2)) {
            showGameEndPopup = true
        }
        isRematchSetupFlow = false
    }

    private var homeButton: some View {
        Button {
            if isReviewMode {
                homeExitFromReviewMode = true
                showHomeExitConfirm = true
            } else if !isGameOver() {
                homeExitFromReviewMode = false
                showHomeExitConfirm = true
            } else {
                returnToStartScreen()
            }
        } label: {
            Image(systemName: "house.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(themeColor)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(themeColor.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .alert(homeExitFromReviewMode ? "検討を終了しますか？" : "対局を終了しますか？", isPresented: $showHomeExitConfirm) {
            Button("終了する", role: .destructive) {
                returnToStartScreen()
            }
            Button("キャンセル", role: .cancel) {
                homeExitFromReviewMode = false
            }
        } message: {
            Text(homeExitFromReviewMode
                 ? "検討モードを終了してホーム画面に戻ります。"
                 : "進行中の対局を終了してホーム画面に戻ります。")
        }
        .accessibilityLabel("初期画面へ戻る")
    }

    private func returnToStartScreen() {
        selected = nil
        selectedDropType = nil
        pendingPromotionMove = nil
        showGameEndPopup = false
        showMatchStartCue = false
        endReviewMode(restoreFinalPosition: false)
        showStartScreen = true
    }

    private var kifIconButton: some View {
        Button {
            openSavedKifSheet()
        } label: {
            Image(systemName: "books.vertical")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(themeColor)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(themeColor.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("保存棋譜")
    }

    private func layoutMetrics(for size: CGSize) -> (isWide: Bool, isPhoneLandscape: Bool, cellSize: CGFloat) {
        let isLandscape = size.width > size.height * 1.05
        // 高さ < 600pt = スマホ横向き（iPadは横向きでも600pt以上）
        let isPhoneLandscape = isLandscape && size.height < 600
        let isWide = size.width >= 820 || (isLandscape && !isPhoneLandscape)
        let cell: CGFloat

        if isPhoneLandscape {
            // 横向きスマホ: 盤面を最大化
            let heightCell = floor(size.height / 9)
            // 右側UI列の最小幅(120) + パッド(12+12) = 144を確保
            let widthCell  = floor((size.width - 144) / 9)
            cell = max(minimumCellSize, min(heightCell, widthCell))
        } else if isWide {
            // iPad横 / 大型iPad縦: 盤面を最大化
            let overhead: CGFloat = 20  // 最小パッド
            let heightCell = floor((size.height - overhead) / 9)
            let widthCell  = floor((size.width - overhead) / 9)
            cell = max(minimumCellSize, min(heightCell, widthCell))
        } else {
            // 縦向きスマホ / iPad mini縦: 盤面を最大化
            let isSmall = size.height < 700
            let overhead: CGFloat = isSmall ? 100 : 140  // 最小化
            let heightCell = floor((size.height - overhead) / 9)
            let hPad: CGFloat = 4  // 最小パッド
            let widthCell  = floor((size.width - hPad * 2) / 9)
            cell = max(minimumCellSize, min(heightCell, widthCell))
        }

        return (isWide, isPhoneLandscape, cell)
    }

    private func compactLayout(cellSize: CGFloat, size: CGSize) -> some View {
        let vSpacing: CGFloat = 2
        let hPad: CGFloat = 4
        let vPad: CGFloat = 2

        return VStack(spacing: vSpacing) {
            VStack(spacing: 2) {
                playerControlPanel(for: .gote, tint: themeColor)
                    .opacity(isReviewMode ? 0 : 1)
                    .allowsHitTesting(!isReviewMode)
                    .accessibilityHidden(isReviewMode)
                compactHandView(for: .gote)
            }

            boardView(cellSize: cellSize)
                .frame(width: cellSize * 9)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 2) {
                compactHandView(for: .sente)
                postGameControls
                    .padding(.top, isReviewMode ? 8 : 0)
                playerControlPanel(for: .sente, tint: themeColor)
                    .opacity(isReviewMode ? 0 : 1)
                    .allowsHitTesting(!isReviewMode)
                    .accessibilityHidden(isReviewMode)
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func wideLayout(cellSize: CGFloat, size: CGSize) -> some View {
        let boardColumnWidth = cellSize * 9
        let sideWidth = max(130, min(320, (size.width - boardColumnWidth) * 0.5 - 8))
        let halfGap = max(0, (size.width - boardColumnWidth) * 0.5)
        let sideTrailingInset = max(0, (halfGap - sideWidth) * 0.2)

        return ZStack {
            // 盤面列は常に中央
            VStack(spacing: 3) {
                compactHandView(for: .gote)
                boardView(cellSize: cellSize)
                    .frame(width: cellSize * 9)
                    .frame(maxWidth: .infinity, alignment: .center)
                compactHandView(for: .sente)
            }
            .frame(width: boardColumnWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // 情報列は右寄せ（盤面中央を崩さない）
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    playerControlPanel(for: .gote, tint: themeColor)
                        .opacity(isReviewMode ? 0 : 1)
                        .allowsHitTesting(!isReviewMode)
                        .accessibilityHidden(isReviewMode)
                    postGameControls
                        .padding(.top, isReviewMode ? 8 : 0)
                    playerControlPanel(for: .sente, tint: themeColor)
                        .opacity(isReviewMode ? 0 : 1)
                        .allowsHitTesting(!isReviewMode)
                        .accessibilityHidden(isReviewMode)
                    Spacer(minLength: 0)
                }
                .frame(width: sideWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.trailing, sideTrailingInset)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 横向きスマホ専用レイアウト
    private func phoneLandscapeLayout(cellSize: CGFloat, size: CGSize) -> some View {
        let boardColumnWidth = cellSize * 9
        let sideWidth = max(120, min(190, (size.width - boardColumnWidth) * 0.5 - 6))
        let halfGap = max(0, (size.width - boardColumnWidth) * 0.5)
        let sideTrailingInset = max(0, (halfGap - sideWidth) * 0.2)

        return ZStack {
            boardView(cellSize: cellSize)
                .frame(width: cellSize * 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    Spacer(minLength: 0)
                    playerControlPanel(for: .gote, tint: themeColor)
                        .opacity(isReviewMode ? 0 : 1)
                        .allowsHitTesting(!isReviewMode)
                        .accessibilityHidden(isReviewMode)
                    compactHandView(for: .gote)
                    compactHandView(for: .sente)
                    playerControlPanel(for: .sente, tint: themeColor)
                        .opacity(isReviewMode ? 0 : 1)
                        .allowsHitTesting(!isReviewMode)
                        .accessibilityHidden(isReviewMode)
                    postGameControls
                        .padding(.top, isReviewMode ? 8 : 0)
                    Spacer(minLength: 0)
                }
                .frame(width: sideWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.trailing, sideTrailingInset)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - コンパクト持ち駒ビュー
    private func compactHandView(for player: Player) -> some View {
        let hand = handDict(for: player)
        let isActiveTurn = !isGameOver() && turn == player
        let isByoYomiAlert = isByoYomiAlertActive(for: player)
        return ViewThatFits(in: .horizontal) {
            compactHandRow(for: player, hand: hand, itemSide: 60, spacing: 7)
            compactHandRow(for: player, hand: hand, itemSide: 54, spacing: 5)
            compactHandRow(for: player, hand: hand, itemSide: 48, spacing: 4)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.cardBg)
                .overlay {
                    if isByoYomiAlert {
                        LinearGradient(
                            colors: [
                                Color(red: 0.70, green: 0.46, blue: 0.05),
                                Color(red: 0.99, green: 0.84, blue: 0.22)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .opacity(byoYomiAlertPulse ? 0.40 : 0.22)
                    }
                }
        )
        .brightness(isByoYomiAlert ? 0.05 : (isActiveTurn ? 0.03 : -0.08))
        .saturation(isByoYomiAlert ? 1.15 : (isActiveTurn ? 1.0 : 0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isByoYomiAlert
                        ? Color(red: 0.97, green: 0.73, blue: 0.12).opacity(byoYomiAlertPulse ? 0.98 : 0.72)
                        : (isActiveTurn ? themeColor.opacity(0.95) : Color.black.opacity(0.06)),
                    lineWidth: isByoYomiAlert ? 2.8 : (isActiveTurn ? 2.2 : 1)
                )
        )
        .shadow(color: isByoYomiAlert ? Color(red: 0.95, green: 0.65, blue: 0.10).opacity(byoYomiAlertPulse ? 0.28 : 0.14) : .clear, radius: 8, y: 0)
    }

    private func compactHandRow(for player: Player, hand: [PieceType: Int], itemSide: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(PieceType.handOrder, id: \.self) { type in
                let count = hand[type, default: 0]
                let canTap = !isGameOver() && turn == player && count > 0
                let isSelected = canTap && selectedDropType == type

                Button(action: {
                    guard canTap else { return }
                    if selectedDropType == type {
                        selectedDropType = nil
                        statusMessage = "打ち駒の選択を解除しました"
                    } else {
                        selectedDropType = type
                        selected = nil
                        statusMessage = "\(type.symbol)を打つ位置を選んでください"
                    }
                }) {
                    compactHandPieceView(type: type, count: count, player: player, isSelected: isSelected, itemSide: itemSide)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func compactHandPieceView(type: PieceType, count: Int, player: Player, isSelected: Bool, itemSide: CGFloat = 52) -> some View {
        let bgColor: Color = {
            if count > 0 {
                return isSelected ? themeColor.opacity(0.42) : themeColor.opacity(0.15)
            }
            return Color.gray.opacity(0.16)
        }()
        let pieceFrame = itemSide * 0.80
        let komaWidth = max(20, itemSide * 0.48)
        let komaHeight = max(24, itemSide * 0.58)
        let fontSize = max(10, itemSide * 0.25)
        
        return ZStack(alignment: .bottomTrailing) {
            komaView(symbol: type.symbol, owner: player, width: komaWidth, height: komaHeight, fontSize: fontSize)
                .frame(width: pieceFrame, height: pieceFrame, alignment: .center)
                .grayscale(count > 0 ? 0 : 1)
                .background(count > 0 ? Palette.neutral.opacity(0.1) : Color.gray.opacity(0.18))
                .clipShape(Circle())
                .overlay(Circle().stroke(count > 0 ? Color.black.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: isSelected ? 1.5 : 1))
            
            if count > 0 {
                VStack(spacing: 0) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? themeColor : .secondary.opacity(0.4))
                        .offset(x: 2, y: -6)
                    
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 16, height: 14, alignment: .center)
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .offset(x: 4, y: 2)
                }
            }
        }
        .frame(width: itemSide, height: itemSide, alignment: .center)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? themeColor : (count > 0 ? themeColor.opacity(0.30) : Color.black.opacity(0.14)), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("\(player.label) \(type.symbol)\(count > 0 ? " \(count)枚" : " なし")\(isSelected ? " 選択中" : "")")
        .accessibilityHint(count > 0 ? "タップして\(type.symbol)を打ち駒として選択" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func handPieceView(type: PieceType, count: Int, player: Player, isSelected: Bool) -> some View {
        let bgColor: Color = {
            if count > 0 {
                return isSelected ? themeColor.opacity(0.42) : themeColor.opacity(0.15)
            }
            return Color.gray.opacity(0.18)
        }()
        
        return ZStack(alignment: .bottomTrailing) {
            komaView(symbol: type.symbol, owner: player, width: 28, height: 32, fontSize: 14)
                .frame(width: 50, height: 50, alignment: .center)
                .grayscale(count > 0 ? 0 : 1)
                .background(count > 0 ? Palette.neutral.opacity(0.12) : Color.gray.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(count > 0 ? Color.black.opacity(0.12) : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                )
            
            if count > 0 {
                VStack(spacing: 0) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? themeColor : .secondary.opacity(0.4))
                        .offset(x: 2, y: -8)
                    
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 20, height: 18, alignment: .center)
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .offset(x: 6, y: 2)
                }
            }
        }
        .frame(width: 56, height: 56, alignment: .center)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? themeColor : (count > 0 ? themeColor.opacity(0.30) : Color.black.opacity(0.12)), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("\(player.label) \(type.symbol)\(count > 0 ? " \(count)枚" : " なし")\(isSelected ? " 選択中" : "")")
        .accessibilityHint(count > 0 ? "タップして\(type.symbol)を打ち駒として選択" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func boardCellAccessibilityLabel(row: Int, col: Int, piece: Piece?, isSelected: Bool, isLegalTarget: Bool) -> String {
        let colLabels = ["９", "８", "７", "６", "５", "４", "３", "２", "１"]
        let rowLabels = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
        let colLabel = colLabels.indices.contains(col) ? colLabels[col] : "\(col + 1)"
        let rowLabel = rowLabels.indices.contains(row) ? rowLabels[row] : "\(row + 1)"
        let squareText = "\(colLabel)\(rowLabel)"

        if let piece {
            let state = isSelected ? " 選択中" : (isLegalTarget ? " 移動可能" : "")
            return "\(squareText) \(piece.owner.label)\(piece.displaySymbol)\(state)"
        }

        if isLegalTarget {
            return "\(squareText) 移動可能な空マス"
        }

        return "\(squareText) 空マス"
    }

    private func boardCellAccessibilityHint(piece: Piece?, isLegalTarget: Bool, isSelected: Bool) -> String {
        if isSelected {
            return "選択を解除できます"
        }
        if isLegalTarget {
            return "タップして移動"
        }
        if let piece, piece.owner == turn, !isGameOver(), !isReviewMode {
            return "タップして選択"
        }
        return ""
    }

    // MARK: - タイトル
    private var modeTitleText: String {
        isReviewMode ? "検討モード" : (isGameOver() ? "終局" : "対局モード")
    }

    private var modeIconName: String {
        isReviewMode ? "magnifyingglass" : (isGameOver() ? "flag.checkered.2.crossed" : "checkerboard.rectangle")
    }

    private var modeSubText: String {
        if isReviewMode {
            return "棋譜を前後して局面を確認"
        }
        if isGameOver() {
            return "結果確認と保存ができます"
        }
        return "現在の手番: \(turn.label)"
    }

    private func compactClockText(for player: Player) -> String {
        let seconds = Int(displayTimerSeconds(for: player).rounded(.down))
        if seconds <= 0 { return "00:00" }

        let minutes = seconds / 60
        let sec = seconds % 60
        return String(format: "%02d:%02d", minutes, sec)
    }
    
    private func isByoYomiAlertActive(for player: Player) -> Bool {
        guard !showStartScreen, !isReviewMode, !isGameOver(), byoYomiSeconds > 0 else { return false }
        guard timerActivePlayer == player else { return false }

        let main = player == .sente ? senteClockRemaining : goteClockRemaining
        let byo = player == .sente ? senteByoYomiRemaining : goteByoYomiRemaining
        return main <= 0 && byo > 0
    }

    private func playerClockStatusText(for player: Player) -> String {
        if !showStartScreen && !isReviewMode && isUnlimitedTimeSetting {
            return "制限時間なし"
        }
        if timerExpiredPlayer == player {
            return "時間切れ"
        }
        let mark = timerActivePlayer == player ? "▶︎ " : ""
        return "\(mark)残り \(compactClockText(for: player))"
    }

    @ViewBuilder
    private func playerClockMiniView(for player: Player) -> some View {
        if !isReviewMode {
            Text(playerClockStatusText(for: player))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(timerActivePlayer == player ? themeColor : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity, alignment: .center)
                .rotationEffect(.degrees(player == .gote ? 180 : 0))
        }
    }

    private var compactModeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: modeIconName)
                .font(.system(size: 11, weight: .bold))
            Text(modeTitleText)
                .font(.caption2.bold())
                .lineLimit(1)
            if !isReviewMode {
                Circle()
                    .fill(turn == .sente ? Palette.turnSente : Palette.turnGote)
                    .frame(width: 8, height: 8)
            }
        }
        .foregroundStyle(themeColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeColor.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(themeColor.opacity(0.28), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var titleSection: some View {
        HStack(spacing: 8) {
            Image(systemName: isReviewMode ? "magnifyingglass" : "checkerboard.rectangle")
                .font(.system(size: 13, weight: .semibold))
            Text(isReviewMode ? "検討モード" : (isGameOver() ? "終局" : "対局モード"))
                .font(.caption.bold())
                .lineLimit(1)
        }
        .foregroundStyle(themeColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(themeColor.opacity(0.10))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(themeColor.opacity(0.25), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func playerControlPanel(for player: Player, tint: Color) -> some View {
        let isMyTurn = !isGameOver() && turn == player
        let isByoYomiAlert = isByoYomiAlertActive(for: player)
        playerControlRow(for: player, tint: tint)
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isByoYomiAlert
                        ? Color(red: 0.97, green: 0.73, blue: 0.12).opacity(byoYomiAlertPulse ? 0.98 : 0.72)
                        : (isMyTurn ? tint.opacity(0.70) : themeColor.opacity(0.18)),
                    lineWidth: isByoYomiAlert ? 2.8 : (isMyTurn ? 2 : 1)
                )
        )
        .opacity(isGameOver() ? 0.6 : (isMyTurn ? 1.0 : 0.55))
    }

    private func playerControlRow(for player: Player, tint: Color) -> some View {
        let isByoYomiAlert = isByoYomiAlertActive(for: player)
        return HStack(spacing: 8) {
            Group {
                if !showStartScreen && !isReviewMode && isUnlimitedTimeSetting {
                    Text("制限時間なし")
                        .font(.footnote.weight(.semibold))
                } else if timerExpiredPlayer == player {
                    Text("時間切れ")
                        .font(.footnote.weight(.semibold))
                } else {
                    HStack(spacing: 4) {
                        if timerActivePlayer == player {
                            Text("▶︎")
                                .font(.caption.bold())
                        }
                        Text("残り")
                            .font(.footnote.weight(.semibold))
                        Text(compactClockText(for: player))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                }
            }
            .foregroundStyle(
                isByoYomiAlert
                    ? Color(red: 0.97, green: 0.73, blue: 0.12).opacity(byoYomiAlertPulse ? 0.98 : 0.72)
                    : (timerActivePlayer == player ? tint : .secondary)
            )
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

            Button {
                resignTargetPlayer = player
                showResignConfirm = true
            } label: {
                Label("投了", systemImage: "flag.fill")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 96, height: 42)
            }
            .buttonStyle(.bordered)
            .tint(
                isByoYomiAlert
                    ? Color(red: 0.97, green: 0.73, blue: 0.12).opacity(byoYomiAlertPulse ? 0.98 : 0.72)
                    : tint
            )
            .disabled(isGameOver() || isReviewMode)
        }
        .rotationEffect(.degrees(player == .gote ? 180 : 0))
    }

    @ViewBuilder
    private var postGameControls: some View {
        if isReviewMode {
            ReviewControlPanelView(
                tint: themeColor,
                isAtStart: reviewIndex == 0,
                isAtEnd: reviewIndex >= reviewSnapshotCount - 1,
                currentIndex: reviewIndex,
                maxIndex: max(reviewSnapshotCount - 1, 0),
                onStart: { goToReviewStart() },
                onBack: { moveReview(by: -1) },
                onForward: { moveReview(by: 1) },
                onEnd: { goToReviewEnd() },
                onScrub: { seekReview(to: $0) },
                onResume: { resumeGameFromCurrentReviewPosition() }
            )
        } else if isGameOver() && hasShownGameEndPopup && !showGameEndPopup && !isGameEndHandled {
            // ポップアップが消えた後でかつ未操作（KIF保存ボタン表示）
            saveFinishedGameButton
        }
    }

    private var saveFinishedGameButton: some View {
        Button {
            saveCurrentRecordToLibrary()
        } label: {
            Label("KIF保存", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(themeColor)
    }

    private var recordLibraryControls: some View {
        Button {
            openSavedKifSheet()
        } label: {
            Label("棋譜", systemImage: "books.vertical")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private var savedKifListView: some View {
        SavedKifListSheetView(
            savedKifFiles: savedKifFiles,
            registeredSources: registeredKifuSources,
            showStartScreen: showStartScreen,
            shouldReloadOnAppear: !isRunningInPreviews,
            leadingToolbarPlacement: leadingToolbarPlacement,
            trailingToolbarPlacement: trailingToolbarPlacement,
            accentTint: Palette.info,
            showRenameKifAlert: $showRenameKifAlert,
            renameTitleInput: $renameTitleInput,
            onSelect: { file in
                openKifuInViewer(.savedFile(file))
                showSavedKifSheet = false
            },
            onOpenSource: { source in
                showSavedKifSheet = false
                openKifuInViewer(.registeredSource(source))
            },
            onDeleteFile: { file in
                deleteSavedKif(file)
            },
            onDeleteOffsets: { offsets in
                deleteSavedKif(at: offsets)
            },
            onDeleteSource: { source in
                deleteRegisteredSource(source)
            },
            onRenameRequest: { file in
                renameTargetFile = file
                renameTitleInput = file.fileName
                showRenameKifAlert = true
            },
            onClose: {
                showSavedKifSheet = false
            },
            onSaveCurrent: {
                saveCurrentRecordToLibrary()
            },
            onImportFile: { url in
                importKifuFile(from: url)
            },
            onImportPastedText: { text in
                await importKifuTextFromPaste(text: text)
            },
            onMoveToFolder: { file, folderName in
                moveKifToFolder(file, to: folderName)
            },
            onRegisterURL: { input in
                await MainActor.run { registerKifuSourceURL(input) }
            },
            onReload: {
                reloadSavedKifFiles()
                reloadRegisteredKifuSources()
                // 登録ソースの新着棋譜を非同期で取得
                if let actor = backgroundKifuActor, !registeredKifuSources.isEmpty {
                    Task {
                        await syncService.syncAll(
                            sources:         registeredKifuSources,
                            backgroundActor: actor
                        )
                        reloadSavedKifFiles()
                        if let result = syncService.lastResult {
                            statusMessage = "同期完了: \(result.summary)"
                        }
                    }
                }
            },
            onRenameSave: {
                guard let target = renameTargetFile else { return }
                renameSavedKif(target, to: renameTitleInput)
            },
            onRenameCancel: {
                renameTargetFile = nil
            },
            isSyncing:            syncService.isSyncing,
            syncProgress:         syncService.syncProgress,
            syncCompletedCount:   syncService.syncCompletedCount,
            syncTotalCount:       syncService.syncTotalCount,
            isNetworkUnavailable: syncService.isNetworkUnavailable,
            hasFailedSources:     !syncService.failedSources.isEmpty,
            onRetryFailed: {
                if let actor = backgroundKifuActor {
                    Task {
                        await syncService.retryFailed(backgroundActor: actor)
                        reloadSavedKifFiles()
                        if let result = syncService.lastResult {
                            statusMessage = "再試行完了: \(result.summary)"
                        }
                    }
                }
            }
        )
    }

    private var urlRegistrationSheetView: some View {
        URLRegistrationSheetView { input in
            await MainActor.run { registerKifuSourceURL(input) }
        }
    }


    private func komaView(symbol: String, owner: Player, width: CGFloat, height: CGFloat, fontSize: CGFloat) -> some View {
        ZStack {
            KomaShape()
                .fill(
                    LinearGradient(
                        colors: [Palette.pieceFillTop, Palette.pieceFillBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            KomaShape()
                .stroke(Palette.pieceBorder, lineWidth: max(1.2, min(width, height) * 0.05))

            Text(symbol)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Palette.pieceText)
                .shadow(color: Palette.pieceShadow, radius: 0.5, x: 0, y: 0)
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(owner == .gote ? 180 : 0))
    }

    private func resetGame(handicap: GameHandicap? = nil, initialTurn: Player? = nil, announceStatus: Bool = true) {
        let applyingHandicap = handicap ?? selectedHandicap
        selectedHandicap = applyingHandicap
        board = ContentView.initialBoard(handicap: applyingHandicap)
        selected = nil
        selectedDropType = nil
        senteHand = [:]
        goteHand = [:]
        pendingPromotionMove = nil
        turn = initialTurn ?? .sente
        winner = nil
        winReason = "詰み"
        isSennichite = false
        isInterrupted = false
        showGameEndPopup = false
        isGameEndHandled = false
        hasShownGameEndPopup = false
        positionCounts = [:]
        moveHistory = []
        moveRecords = []
        reviewFinalSnapshot = nil
        reviewIndex = 0
        isReviewMode = false
        if announceStatus {
            statusMessage = "リセットしました"
        }
        registerCurrentPositionIfNeeded()
    }

    private func handView(for player: Player) -> some View {
        let hand = handDict(for: player)
        let isActiveTurn = !isGameOver() && turn == player
        let isByoYomiAlert = isByoYomiAlertActive(for: player)
        let columns = [GridItem(.adaptive(minimum: 56, maximum: 56), spacing: 8)]

        return VStack(alignment: .center, spacing: 6) {
            LazyVGrid(columns: columns, alignment: .center, spacing: 8) {
                ForEach(PieceType.handOrder, id: \.self) { type in
                    let count = hand[type, default: 0]
                    let canTap = !isGameOver() && turn == player && count > 0
                    let isSelected = canTap && selectedDropType == type

                    Button(action: {
                        guard canTap else { return }
                        if selectedDropType == type {
                            selectedDropType = nil
                            statusMessage = "打ち駒の選択を解除しました"
                        } else {
                            selectedDropType = type
                            selected = nil
                            statusMessage = "\(type.symbol)を打つ位置を選んでください"
                        }
                    }) {
                        handPieceView(type: type, count: count, player: player, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.cardBg)
                .overlay {
                    if isByoYomiAlert {
                        LinearGradient(
                            colors: [
                                Color(red: 0.70, green: 0.46, blue: 0.05),
                                Color(red: 0.99, green: 0.84, blue: 0.22)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .opacity(byoYomiAlertPulse ? 0.40 : 0.22)
                    }
                }
        )
        .brightness(isByoYomiAlert ? 0.05 : (isActiveTurn ? 0.03 : -0.08))
        .saturation(isByoYomiAlert ? 1.15 : (isActiveTurn ? 1.0 : 0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isByoYomiAlert
                        ? Color(red: 0.97, green: 0.73, blue: 0.12).opacity(byoYomiAlertPulse ? 0.98 : 0.72)
                        : (isActiveTurn ? themeColor.opacity(0.95) : Color.black.opacity(0.06)),
                    lineWidth: isByoYomiAlert ? 2.8 : (isActiveTurn ? 2.2 : 1)
                )
        )
        .shadow(color: isByoYomiAlert ? Color(red: 0.95, green: 0.65, blue: 0.10).opacity(byoYomiAlertPulse ? 0.28 : 0.14) : .clear, radius: 8, y: 0)
    }

    private func boardView(cellSize: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: 9)
        let legalTargets = currentLegalTargets()

        // 振り駒中に非表示にする後手の歩（中央5枚: col=2〜6）のSquare集合
        let furigomaHiddenSquares: Set<Square> = {
            guard showFurigomaCue else { return [] }
            return Set((2...6).compactMap { c -> Square? in
                guard let piece = board[2][c], piece.owner == .gote, piece.type == .pawn else { return nil }
                return Square(row: 2, col: c)
            })
        }()

        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<81, id: \.self) { idx in
                let row = idx / 9
                let col = idx % 9
                let square = Square(row: row, col: col)
                let isSelected = selected == square
                let isLegalTarget = legalTargets.contains(square)
                let isCaptureTarget = isLegalTarget && board[row][col] != nil
                let pieceFontSize = max(18, cellSize * 0.56)
                let markerSize = max(10, cellSize * 0.34)
                let captureRingSize = max(cellSize - 10, cellSize * 0.72)
                let captureXSize = max(9, cellSize * 0.28)
                let selectedViewfinderSize = max(12, cellSize * 0.38)

                boardCell(
                    cellSize: cellSize,
                    square: square,
                    row: row,
                    col: col,
                    isSelected: isSelected,
                    isLegalTarget: isLegalTarget,
                    isCaptureTarget: isCaptureTarget,
                    pieceFontSize: pieceFontSize,
                    markerSize: markerSize,
                    captureRingSize: captureRingSize,
                    captureXSize: captureXSize,
                    selectedViewfinderSize: selectedViewfinderSize,
                    furigomaHiddenSquares: furigomaHiddenSquares
                )
            }
        }
        .padding(8)
        .background(Palette.boardFrame.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
            .stroke(Palette.boardFrame.opacity(0.6), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.opacity(isReviewMode ? 0.30 : 0.22), lineWidth: 1)
                .padding(1)
        )
        .anchorPreference(key: BoardFrameAnchorKey.self, value: .bounds) { $0 }
        .shadow(color: themeColor.opacity(isReviewMode ? 0.16 : 0.09), radius: 8, x: 0, y: 3)
    }

    // 棋盤セル（分離して最適化）
    @ViewBuilder
    private func boardCell(
        cellSize: CGFloat,
        square: Square,
        row: Int,
        col: Int,
        isSelected: Bool,
        isLegalTarget: Bool,
        isCaptureTarget: Bool,
        pieceFontSize: CGFloat,
        markerSize: CGFloat,
        captureRingSize: CGFloat,
        captureXSize: CGFloat,
        selectedViewfinderSize: CGFloat,
        furigomaHiddenSquares: Set<Square>
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(isSelected ? Palette.hintSelected.opacity(0.20) : squareColor(row: row, col: col))
                .frame(width: cellSize, height: cellSize)
                .overlay(
                    Rectangle()
                        .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                )

            if isSelected {
                boardCellSelected(
                    cellSize: cellSize,
                    selectedViewfinderSize: selectedViewfinderSize
                )
            }

            if isLegalTarget {
                if isCaptureTarget {
                    boardCellCapture(
                        markerSize: markerSize,
                        captureRingSize: captureRingSize,
                        captureXSize: captureXSize
                    )
                } else {
                    boardCellLegalMove(markerSize: markerSize)
                }
            }

            if let piece = board[row][col] {
                let hiddenDuringFurigoma = furigomaHiddenSquares.contains(square)
                komaView(
                    symbol: piece.displaySymbol,
                    owner: piece.owner,
                    width: cellSize * 0.80,
                    height: cellSize * 0.86,
                    fontSize: pieceFontSize * 0.92
                )
                .opacity(hiddenDuringFurigoma ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: showFurigomaCue)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.98))
                ))
            }
        }
        .animation(isReviewMode ? .none : .interactiveSpring(response: 0.18, dampingFraction: 0.86), value: boardMotionTick)
        .contentShape(Rectangle())
        .accessibilityLabel(boardCellAccessibilityLabel(row: row, col: col, piece: board[row][col], isSelected: isSelected, isLegalTarget: isLegalTarget))
        .accessibilityHint(boardCellAccessibilityHint(piece: board[row][col], isLegalTarget: isLegalTarget, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onTapGesture {
            handleTap(row: row, col: col)
        }
    }

    // 選択状態のセル表示
    @ViewBuilder
    private func boardCellSelected(cellSize: CGFloat, selectedViewfinderSize: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .stroke(
                Palette.hintSelectedBorder,
                style: StrokeStyle(lineWidth: 2.4, dash: [6, 2])
            )
            .frame(width: cellSize - 2, height: cellSize - 2)
        RoundedRectangle(cornerRadius: 3)
            .stroke(Palette.hintSelectedBorder.opacity(0.45), lineWidth: 1)
            .frame(width: cellSize - 8, height: cellSize - 8)
        Image(systemName: "viewfinder")
            .font(.system(size: selectedViewfinderSize, weight: .bold))
            .foregroundStyle(Palette.hintSelectedBorder.opacity(0.90))
    }

    // 駒がある合法移動先（キャプチャ）
    @ViewBuilder
    private func boardCellCapture(
        markerSize: CGFloat,
        captureRingSize: CGFloat,
        captureXSize: CGFloat
    ) -> some View {
        Circle()
            .stroke(
                Palette.hintCapture,
                style: StrokeStyle(lineWidth: 2.4, dash: [4, 2])
            )
            .frame(width: captureRingSize, height: captureRingSize)
        Image(systemName: "xmark")
            .font(.system(size: captureXSize, weight: .black))
            .foregroundStyle(Palette.hintCapture)
    }
    // 空の合法移動先
    @ViewBuilder
    private func boardCellLegalMove(markerSize: CGFloat) -> some View {
        Image(systemName: "diamond.fill")
            .font(.system(size: markerSize, weight: .bold))
            .foregroundStyle(Palette.hintMove)
        Image(systemName: "diamond")
            .font(.system(size: markerSize, weight: .bold))
            .foregroundStyle(.white.opacity(0.95))
    }

    private func currentLegalTargets() -> Set<Square> {
        if isGameOver() {
            return []
        }

        if let type = selectedDropType {
            return legalDropTargets(for: type, owner: turn)
        }

        guard let from = selected, let piece = board[from.row][from.col], piece.owner == turn else {
            return []
        }

        var targets: Set<Square> = []
        let candidates = pseudoLegalTargets(for: piece, from: from, on: board)

        for to in candidates {
            guard canMovePiece(on: board, from: from, to: to) else { continue }
            let promotion = promotionState(for: piece, from: from, to: to)

            if promotion.mustPromote {
                if isLegalAfterMove(from: from, to: to, owner: piece.owner, promote: true) {
                    targets.insert(to)
                }
            } else if promotion.canPromote {
                if isLegalAfterMove(from: from, to: to, owner: piece.owner, promote: false)
                    || isLegalAfterMove(from: from, to: to, owner: piece.owner, promote: true) {
                    targets.insert(to)
                }
            } else {
                if isLegalAfterMove(from: from, to: to, owner: piece.owner, promote: false) {
                    targets.insert(to)
                }
            }
        }

        return targets
    }

    private func legalDropTargets(for type: PieceType, owner: Player) -> Set<Square> {
        var targets: Set<Square> = []

        for row in 0..<9 {
            for col in 0..<9 {
                let to = Square(row: row, col: col)
                guard board[row][col] == nil else { continue }
                guard isLegalDrop(type: type, to: to, owner: owner) else { continue }
                guard let nextBoard = boardByApplyingDrop(on: board, type: type, to: to, owner: owner) else { continue }
                guard !isInCheck(player: owner, on: nextBoard) else { continue }
                guard !isIllegalPawnDropMate(type: type, owner: owner, boardAfterDrop: nextBoard) else { continue }
                targets.insert(to)
            }
        }

        return targets
    }

    private func squareColor(row: Int, col: Int) -> Color {
        Palette.boardLight
    }

    private func handleTap(row: Int, col: Int) {
        if isGameOver() {
            statusMessage = "対局終了中です。最初からを押してください"
            return
        }

        let tapped = Square(row: row, col: col)
        let tappedPiece = board[row][col]

        if let dropType = selectedDropType {
            handleDrop(type: dropType, to: tapped)
            return
        }

        guard let currentSelection = selected else {
            if let piece = tappedPiece, piece.owner == turn {
                selected = tapped
                statusMessage = "\(piece.displaySymbol)を選択中"
            } else {
                statusMessage = "\(turn.label)の駒を選んでください"
            }
            return
        }

        if currentSelection == tapped {
            selected = nil
            statusMessage = "選択を解除しました"
            return
        }

        if let piece = tappedPiece, piece.owner == turn {
            selected = tapped
            statusMessage = "\(piece.displaySymbol)に選択を変更"
            return
        }

        if isLegalMove(from: currentSelection, to: tapped) {
            if let movingPiece = board[currentSelection.row][currentSelection.col] {
                let promotion = promotionState(for: movingPiece, from: currentSelection, to: tapped)
                let canMoveWithoutPromote = isLegalAfterMove(from: currentSelection, to: tapped, owner: movingPiece.owner, promote: false)
                let canMoveWithPromote = promotion.canPromote && isLegalAfterMove(from: currentSelection, to: tapped, owner: movingPiece.owner, promote: true)

                if promotion.mustPromote {
                    if canMoveWithPromote {
                        executeMove(from: currentSelection, to: tapped, promote: true)
                    } else {
                        statusMessage = "王手を受ける形になるため、その手は指せません"
                    }
                } else if promotion.canPromote {
                    if canMoveWithPromote && canMoveWithoutPromote {
                        pendingPromotionMove = PendingPromotionMove(from: currentSelection, to: tapped)
                    } else if canMoveWithPromote {
                        executeMove(from: currentSelection, to: tapped, promote: true)
                    } else if canMoveWithoutPromote {
                        executeMove(from: currentSelection, to: tapped, promote: false)
                    } else {
                        statusMessage = "王手を受ける形になるため、その手は指せません"
                    }
                } else {
                    if canMoveWithoutPromote {
                        executeMove(from: currentSelection, to: tapped, promote: false)
                    } else {
                        statusMessage = "王手を受ける形になるため、その手は指せません"
                    }
                }
            }
        } else {
            statusMessage = "その場所には移動できません"
        }
    }

    private func executeMove(from: Square, to: Square, promote: Bool) {
        guard var movingPiece = board[from.row][from.col] else { return }

        saveSnapshotForUndo()

        let capturedPiece = board[to.row][to.col]

        if let captured = capturedPiece {
            addToHand(owner: movingPiece.owner, type: captured.type)
        }

        board[from.row][from.col] = nil

        if promote, movingPiece.type.canPromote {
            movingPiece.isPromoted = true
        }

        board[to.row][to.col] = movingPiece
        boardMotionTick &+= 1
        appendMoveRecord(GameEngine.formatMoveRecord(player: movingPiece.owner, piece: movingPiece, from: from, to: to, captured: capturedPiece, promote: promote))
        selected = nil
        selectedDropType = nil
        advanceTurnAndUpdateStatus(movedBy: movingPiece.owner, action: "移動しました")
    }

    private func handleDrop(type: PieceType, to: Square) {
        guard board[to.row][to.col] == nil else {
            statusMessage = "駒があるマスには打てません"
            return
        }

        guard handDict(for: turn)[type, default: 0] > 0 else {
            selectedDropType = nil
            statusMessage = "その駒は持っていません"
            return
        }

        guard isLegalDrop(type: type, to: to, owner: turn) else {
            statusMessage = "その場所には打てません"
            return
        }

        guard let nextBoard = boardByApplyingDrop(on: board, type: type, to: to, owner: turn), !isInCheck(player: turn, on: nextBoard) else {
            statusMessage = "王手を受ける形になるため、その場所には打てません"
            return
        }

        if isIllegalPawnDropMate(type: type, owner: turn, boardAfterDrop: nextBoard) {
            statusMessage = "打ち歩詰めはできません"
            return
        }

        saveSnapshotForUndo()

        useFromHand(owner: turn, type: type)
        board = nextBoard
        boardMotionTick &+= 1
        let mover = turn
        appendMoveRecord(GameEngine.formatDropRecord(player: mover, type: type, to: to))
        selectedDropType = nil
        selected = nil
        advanceTurnAndUpdateStatus(movedBy: mover, action: "駒を打ちました")
    }

    private func isIllegalPawnDropMate(type: PieceType, owner: Player, boardAfterDrop: [[Piece?]]) -> Bool {
        guard type == .pawn else { return false }

        let defender = owner.opposite
        guard isInCheck(player: defender, on: boardAfterDrop) else {
            return false
        }

        return isCheckmate(player: defender, on: boardAfterDrop, senteHandState: senteHand, goteHandState: goteHand)
    }

    private func isGameOver() -> Bool {
        winner != nil || isSennichite || isInterrupted
    }

    private var reviewStatusText: String {
        if reviewSnapshotCount == 0 {
            return "検討モード"
        }

        if reviewIndex == 0 {
            return "検討モード: 初期局面"
        }

        if reviewIndex == reviewSnapshotCount - 1 {
            return "検討モード: 終局局面"
        }

        return "検討モード: \(reviewIndex)手目"
    }

    private func currentSnapshot() -> GameSnapshot {
        GameSnapshot(
            board: board,
            selected: selected,
            selectedDropType: selectedDropType,
            senteHand: senteHand,
            goteHand: goteHand,
            pendingPromotionMove: pendingPromotionMove,
            turn: turn,
            winner: winner,
            winReason: winReason,
            isSennichite: isSennichite,
            isInterrupted: isInterrupted,
            positionCounts: positionCounts,
            moveRecords: moveRecords
        )
    }

    private func reviewSnapshot(from snapshot: GameSnapshot) -> GameSnapshot {
        // ボード検証のみ実行（余計な GameSnapshot 作成をスキップしてメモリ節約）
        let safeBoard = sanitizedBoard(snapshot.board)
        return GameSnapshot(
            board: safeBoard,
            selected: nil,
            selectedDropType: nil,
            senteHand: snapshot.senteHand,
            goteHand: snapshot.goteHand,
            pendingPromotionMove: nil,
            turn: snapshot.turn,
            winner: snapshot.winner,
            winReason: snapshot.winReason,
            isSennichite: snapshot.isSennichite,
            isInterrupted: snapshot.isInterrupted,
            positionCounts: snapshot.positionCounts,
            moveRecords: snapshot.moveRecords
        )
    }

    private func apply(snapshot: GameSnapshot) {
        let safe = sanitizedSnapshot(snapshot)
        board = safe.board
        selected = nil
        selectedDropType = nil
        senteHand = safe.senteHand
        goteHand = safe.goteHand
        pendingPromotionMove = nil
        turn = safe.turn
        winner = safe.winner
        winReason = safe.winReason
        isSennichite = safe.isSennichite
        isInterrupted = safe.isInterrupted
        positionCounts = safe.positionCounts
        moveRecords = safe.moveRecords
    }

    private func sanitizedSnapshot(_ snapshot: GameSnapshot) -> GameSnapshot {
        let safeBoard = sanitizedBoard(snapshot.board)
        return GameSnapshot(
            board: safeBoard,
            selected: nil,
            selectedDropType: nil,
            senteHand: snapshot.senteHand,
            goteHand: snapshot.goteHand,
            pendingPromotionMove: nil,
            turn: snapshot.turn,
            winner: snapshot.winner,
            winReason: snapshot.winReason,
            isSennichite: snapshot.isSennichite,
            isInterrupted: snapshot.isInterrupted,
            positionCounts: snapshot.positionCounts,
            moveRecords: snapshot.moveRecords
        )
    }

    private func sanitizedBoard(_ boardCandidate: [[Piece?]]) -> [[Piece?]] {
        var normalized = ContentView.initialBoard(handicap: .none)
        for row in 0..<9 {
            guard boardCandidate.indices.contains(row) else { continue }
            let sourceRow = boardCandidate[row]
            for col in 0..<9 {
                guard sourceRow.indices.contains(col) else { continue }
                normalized[row][col] = sourceRow[col]
            }
        }
        return normalized
    }

    private var reviewSnapshotCount: Int {
        if reviewSourceText != nil {
            return reviewFinalSnapshot == nil ? 0 : reviewLoadedMoveCount + 1
        }
        return reviewFinalSnapshot == nil ? 0 : moveHistory.count + 1
    }

    private func snapshotForReview(at index: Int) -> GameSnapshot? {
        guard let finalSnapshot = reviewFinalSnapshot else { return nil }
        let normalizedIndex = min(max(index, 0), reviewSnapshotCount - 1)
        if let cached = reviewSnapshotCache[normalizedIndex] {
            return cached
        }

        if let sourceText = reviewSourceText {
            if normalizedIndex == reviewLoadedMoveCount {
                let snapshot = reviewSnapshot(from: finalSnapshot)
                // キャッシュサイズ制限 (最大20個)
                addToReviewSnapshotCache(snapshot, at: normalizedIndex)
                return snapshot
            }
            if let parsed = try? KifuParser.parse(text: sourceText, upToMoveCount: normalizedIndex, includeHistory: false) {
                let snapshot = reviewSnapshot(from: parsed.record.snapshot)
                addToReviewSnapshotCache(snapshot, at: normalizedIndex)
                return snapshot
            }
            return nil
        }

        if normalizedIndex < moveHistory.count {
            let snapshot = reviewSnapshot(from: moveHistory[normalizedIndex])
            addToReviewSnapshotCache(snapshot, at: normalizedIndex)
            return snapshot
        }
        let snapshot = reviewSnapshot(from: finalSnapshot)
        addToReviewSnapshotCache(snapshot, at: normalizedIndex)
        return snapshot
    }

    private func addToReviewSnapshotCache(_ snapshot: GameSnapshot, at index: Int) {
        let maxCacheSize = 20
        if reviewSnapshotCache.count >= maxCacheSize {
            // 最小インデックスを削除（LRU）
            if let minKey = reviewSnapshotCache.keys.min() {
                reviewSnapshotCache.removeValue(forKey: minKey)
            }
        }
        reviewSnapshotCache[index] = snapshot
    }

    private func enterReviewModeFromOverlay() {
        isGameEndHandled = true
        showGameEndPopup = false
        suppressGameEndPopup = true

        DispatchQueue.main.async {
            startReviewMode()
        }
    }

    @MainActor
    private func activateReviewMode(
        finalSnapshot: GameSnapshot,
        history: [GameSnapshot],
        sourceText: String? = nil,
        status: String
    ) {
        let safeHistory = history.map(sanitizedSnapshot)
        let safeFinal = sanitizedSnapshot(finalSnapshot)

        suppressGameEndPopup = true
        showGameEndPopup = false
        moveHistory = safeHistory
        reviewFinalSnapshot = safeFinal
        reviewSourceText = sourceText
        reviewSnapshotCache = [:]
        reviewLoadedMoveCount = safeFinal.moveRecords.count
        reviewIndex = sourceText != nil ? max(reviewLoadedMoveCount, 0) : max(safeHistory.count, 0)
        isReviewMode = true
        showStartScreen = false

        if let snapshot = snapshotForReview(at: reviewIndex) {
            apply(snapshot: snapshot)
        } else {
            apply(snapshot: safeFinal)
        }
        statusMessage = status

        DispatchQueue.main.async {
            suppressGameEndPopup = false
        }
    }

    private func startReviewMode() {
        activateReviewMode(
            finalSnapshot: currentSnapshot(),
            history: moveHistory,
            status: reviewStatusText
        )
    }

    private func moveReview(by delta: Int) {
        guard isReviewMode, reviewSnapshotCount > 0 else { return }

        let nextIndex = min(max(reviewIndex + delta, 0), reviewSnapshotCount - 1)
        guard nextIndex != reviewIndex else { return }

        reviewIndex = nextIndex
        if let snapshot = snapshotForReview(at: nextIndex) {
            apply(snapshot: snapshot)
        }
        statusMessage = reviewStatusText
    }

    private func seekReview(to index: Int) {
        guard isReviewMode, reviewSnapshotCount > 0 else { return }

        let nextIndex = min(max(index, 0), reviewSnapshotCount - 1)
        guard nextIndex != reviewIndex else { return }

        reviewIndex = nextIndex
        if let snapshot = snapshotForReview(at: nextIndex) {
            apply(snapshot: snapshot)
        }
        statusMessage = reviewStatusText
    }

    private func goToReviewStart() {
        guard isReviewMode, reviewSnapshotCount > 0 else { return }
        reviewIndex = 0
        if let snapshot = snapshotForReview(at: 0) {
            apply(snapshot: snapshot)
        }
        statusMessage = reviewStatusText
    }

    private func goToReviewEnd() {
        guard isReviewMode, reviewSnapshotCount > 0 else { return }
        reviewIndex = reviewSnapshotCount - 1
        if let snapshot = snapshotForReview(at: reviewIndex) {
            apply(snapshot: snapshot)
        }
        statusMessage = reviewStatusText
    }

    private func endReviewMode(restoreFinalPosition: Bool = true) {
        if restoreFinalPosition, let finalSnapshot = reviewFinalSnapshot {
            apply(snapshot: finalSnapshot)
        }
        reviewFinalSnapshot = nil
        reviewSourceText = nil
        reviewSnapshotCache = [:]
        reviewLoadedMoveCount = 0
        reviewIndex = 0
        isReviewMode = false
        if restoreFinalPosition, isGameOver() {
            statusMessage = "終局局面に戻りました"
        }
    }

    private func resumeGameFromCurrentReviewPosition() {
        guard isReviewMode, reviewSnapshotCount > 0 else { return }

        let resumeIndex = min(max(reviewIndex, 0), reviewSnapshotCount - 1)
        if reviewSourceText != nil {
            var rebuiltHistory: [GameSnapshot] = []
            if resumeIndex > 0 {
                for index in 0..<resumeIndex {
                    if let snapshot = reviewSnapshotCache[index] ?? snapshotForReview(at: index) {
                        rebuiltHistory.append(snapshot)
                    }
                }
            }
            moveHistory = rebuiltHistory
            reviewSourceText = nil
        } else {
            moveHistory = Array(moveHistory.prefix(resumeIndex))
        }

        selected = nil
        selectedDropType = nil
        pendingPromotionMove = nil
        showGameEndPopup = false
        suppressGameEndPopup = false

        winner = nil
        winReason = "詰み"
        isSennichite = false
        isInterrupted = false

        // この局面から再開時は制限時間なしにする
        senteInitialSeconds = 0
        goteInitialSeconds = 0
        byoYomiSeconds = 0
        resetTimerClocks()

        endReviewMode(restoreFinalPosition: false)

        positionCounts = [:]
        registerCurrentPositionIfNeeded()

        statusMessage = "この局面から対局を再開しました（\(turn.label)の手番）"
    }

    private func saveSnapshotForUndo() {
        moveHistory.append(currentSnapshot())
    }

    private func appendMoveRecord(_ record: String) {
        moveRecords.append(record)
    }

    private var snapshotForPersistence: GameSnapshot {
        if isReviewMode, let finalSnapshot = reviewFinalSnapshot {
            return finalSnapshot
        }
        return currentSnapshot()
    }

    private func recordsDirectoryURL() throws -> URL {
        try KifStore.recordsDirectoryURL(isRunningInPreviews: isRunningInPreviews)
    }

    private func currentPersistedRecord() -> PersistedGameRecord {
        PersistedGameRecord(
            snapshot: snapshotForPersistence,
            moveHistory: moveHistory,
            savedAt: Date()
        )
    }

    private func kifFileName(for savedAt: Date, moveCount: Int) -> String {
        KifuCodec.fileName(for: savedAt, moveCount: moveCount)
    }

    private func generateKifText(from record: PersistedGameRecord) -> String {
        KifuCodec.encode(record)
    }

    private func decodePersistedRecord(from text: String) throws -> PersistedGameRecord {
        try KifuCodec.decode(from: text)
    }

    private func normalizedKifTitle(_ title: String) -> String {
        title.replacingOccurrences(of: ".kif", with: "", options: [.caseInsensitive])
    }

    private func folderAssignmentFileKey(_ url: URL) -> String {
        "file:\(url.standardizedFileURL.path)"
    }

    private func folderAssignmentDBKey(_ id: UUID) -> String {
        "db:\(id.uuidString.lowercased())"
    }

    private func folderAssignmentTitleKey(_ title: String) -> String {
        "title:\(normalizedKifTitle(title))"
    }

    private func inferredFolderName(for fileURL: URL, baseDirectoryURL: URL) -> String {
        let parent = fileURL.deletingLastPathComponent().standardizedFileURL.path
        let base = baseDirectoryURL.standardizedFileURL.path

        guard parent.hasPrefix(base) else { return "" }
        var relative = String(parent.dropFirst(base.count))
        if relative.hasPrefix("/") { relative.removeFirst() }
        return relative
    }

    private func loadFolderAssignments() -> [String: String] {
        guard let data = savedKifFolderAssignmentsRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveFolderAssignments(_ assignments: [String: String]) {
        if let data = try? JSONEncoder().encode(assignments),
           let raw = String(data: data, encoding: .utf8) {
            savedKifFolderAssignmentsRaw = raw
        }
    }

    private func repositoryRecord(for file: SavedKifFile) -> KifuRecord? {
        if let byId = try? repository.fetch(id: file.id) {
            return byId
        }
        if let byTitle = try? repository.fetch(title: normalizedKifTitle(file.fileName)) {
            return byTitle
        }

        // 念のため: Predicateで拾えないケース向けに全件走査フォールバック
        if let all = try? repository.fetchAll() {
            let normalized = normalizedKifTitle(file.fileName)
            return all.first { normalizedKifTitle($0.title) == normalized }
        }

        return nil
    }

    private func reloadSavedKifFiles() {
        // プレビュー環境ではリロードをスキップ
        if isRunningInPreviews {
            savedKifReloadTask?.cancel()
            savedKifFiles = []
            return
        }

        let folderAssignments = loadFolderAssignments()
        let dbRecords: [SavedKifDBSnapshot] = ((try? repository.fetchAll()) ?? []).map {
            SavedKifDBSnapshot(
                id: $0.id,
                title: $0.title,
                createdAt: $0.createdAt,
                resultSummary: $0.resultSummary,
                moveCount: $0.moveCount,
                sourceURL: $0.sourceURL,
                folderName: $0.folderName
            )
        }

        savedKifReloadTask?.cancel()
        savedKifReloadTask = Task {
            let files = await Task.detached(priority: .userInitiated) { () -> [SavedKifFile] in
                var files: [SavedKifFile] = []
                let dbRecordByTitle = Dictionary(
                    dbRecords.map { ($0.title, $0) },
                    uniquingKeysWith: { first, _ in first }
                )

                if let directoryURL = try? KifStore.recordsDirectoryURL(isRunningInPreviews: false),
                   let urls = try? KifStore.listKifURLs(in: directoryURL) {
                    let fileItems: [SavedKifFile] = urls.compactMap { url in
                        guard let text = try? KifStore.readText(at: url) else { return nil }
                        let (moveCount, resultStr) = KifuCodec.parseMetadata(from: text)
                        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                        let savedAt = values?.contentModificationDate ?? Date()
                        let title = url.deletingPathExtension().lastPathComponent
                        let summary = "\(resultStr)・\(moveCount)手"
                        let dbRecord = dbRecordByTitle[title]
                        let inferredFolder = inferredFolderName(for: url, baseDirectoryURL: directoryURL)
                        let assignedFolder =
                            folderAssignments[folderAssignmentFileKey(url)] ??
                            (dbRecord.map { folderAssignments[folderAssignmentDBKey($0.id)] } ?? nil) ??
                            folderAssignments[folderAssignmentTitleKey(title)] ??
                            dbRecord?.folderName ??
                            inferredFolder
                        return SavedKifFile(
                            id: dbRecord?.id ?? UUID(),
                            fileURL: url,
                            fileName: title,
                            savedAt: savedAt,
                            summary: summary,
                            folderName: assignedFolder
                        )
                    }
                    files.append(contentsOf: fileItems)
                }

                let existingTitles = Set(files.map { $0.fileName })
                let dbOnly = dbRecords
                    .filter { $0.sourceURL != nil && !existingTitles.contains($0.title) }
                    .map { record in
                        let assignedFolder =
                            folderAssignments[folderAssignmentDBKey(record.id)] ??
                            folderAssignments[folderAssignmentTitleKey(record.title)] ??
                            record.folderName
                        return SavedKifFile(
                            id: record.id,
                            fileURL: nil,
                            fileName: record.title,
                            savedAt: record.createdAt,
                            summary: "\(record.resultSummary)・\(record.moveCount)手",
                            folderName: assignedFolder
                        )
                    }
                files.append(contentsOf: dbOnly)
                return files.sorted { $0.savedAt > $1.savedAt }
            }.value

            guard !Task.isCancelled else { return }
            savedKifFiles = files
            savedKifReloadTask = nil
        }
    }

    private func mergeSavedKifFileIntoList(_ file: SavedKifFile) {
        var next = savedKifFiles.filter { $0.listIdentity != file.listIdentity }
        next.append(file)
        savedKifFiles = next.sorted { $0.savedAt > $1.savedAt }
    }

    private func openSavedKifSheet() {
        if !isRunningInPreviews {
            reloadSavedKifFiles()
            reloadRegisteredKifuSources()
        }
        showSavedKifSheet = true
    }

    private func saveCurrentRecordToLibrary() {
        // プレビュー環境では操作をスキップ
        if isRunningInPreviews {
            statusMessage = "プレビュー環境では KIF 保存は利用できません"
            return
        }
        guard !isSavingKif else { return }
        isSavingKif = true
        defer { isSavingKif = false }

        let record = currentPersistedRecord()
        let text = generateKifText(from: record)
        let preferredTitle = kifFileName(for: record.savedAt, moveCount: record.snapshot.moveRecords.count)
        let resultSummary = GameEngine.resultSummary(for: record.snapshot)
        let moveCount = record.snapshot.moveRecords.count
        let savedFileURL: URL
        let savedTitle: String
        let savedAt: Date

        // ── 一次ストレージ: ファイル（従来どおり確実に保存）──
        do {
            let directoryURL = try recordsDirectoryURL()
            let fileURL = KifStore.uniqueFileURL(for: preferredTitle, in: directoryURL)
            try KifStore.writeText(text, to: fileURL)
            _ = try KifStore.readText(at: fileURL)
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            savedAt = values?.contentModificationDate ?? record.savedAt
            savedFileURL = fileURL
            savedTitle = fileURL.deletingPathExtension().lastPathComponent
            statusMessage = "KIF をアプリ内に保存しました"
        } catch {
            statusMessage = "KIF の保存に失敗しました: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
            return  // ファイル書き込みが失敗した場合はDBも書かない
        }

        mergeSavedKifFileIntoList(
            SavedKifFile(
                url: savedFileURL,
                fileName: savedTitle,
                savedAt: savedAt,
                summary: "\(resultSummary)・\(moveCount)手",
                folderName: ""
            )
        )

        // ── 二次ストレージ: SwiftData（ベストエフォート）──
        let titleWithoutExt = normalizedKifTitle(savedTitle)
        let kifRecord = KifuRecord(
            title: titleWithoutExt,
            kifText: text,
            moveCount: moveCount,
            resultSummary: resultSummary,
            createdAt: savedAt
        )
        do {
            try upsertSavedKifRecord(kifRecord)
        } catch {
            statusMessage = "KIF は保存しましたが、ライブラリ登録に失敗しました: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
        }
        
        // 保存操作のUI更新と競合しないよう次ループで一覧を再構築
        DispatchQueue.main.async {
            reloadSavedKifFiles()
        }
    }

    private func upsertSavedKifRecord(_ incoming: KifuRecord) throws {
        if let existing = (try? repository.fetch(title: incoming.title)) ?? nil {
            existing.kifText = incoming.kifText
            existing.moveCount = incoming.moveCount
            existing.resultSummary = incoming.resultSummary
            existing.createdAt = incoming.createdAt
            try modelContext.save()
            return
        }
        try repository.insert(incoming)
    }

    private func prepareKifExport() {
        let record = currentPersistedRecord()
        let text = copyFriendlyKifText(from: generateKifText(from: record))
        let filename = kifFileName(for: record.savedAt, moveCount: record.snapshot.moveRecords.count)

        do {
            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("87hanafubuki_kif_exports", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

            let fileURL = tempDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            try text.write(to: fileURL, atomically: true, encoding: .utf8)

            lastExportedKifTempURL = fileURL
            exportKifShareItem = KifExportShareItem(url: fileURL)
            statusMessage = "共有先を選択してKIFを出力してください"
        } catch {
            statusMessage = "KIFファイルの出力準備に失敗しました"
        }
    }

    private func copyFriendlyKifText(from fullText: String) -> String {
        let lines = fullText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let payloadPrefix = "*87HANAFUBUKI_STATE:"
        var filtered: [String] = []

        for (index, line) in lines.enumerated() {
            if line.hasPrefix(payloadPrefix) {
                continue
            }
            if line == "*",
               index + 1 < lines.count,
               lines[index + 1].hasPrefix(payloadPrefix) {
                continue
            }
            filtered.append(line)
        }

        return filtered.joined(separator: "\n")
    }

    private func cleanupExportedKifTempFile() {
        guard let url = lastExportedKifTempURL else { return }
        try? FileManager.default.removeItem(at: url)
        lastExportedKifTempURL = nil
    }

    private func reloadRegisteredKifuSources() {
        registeredKifuSources = URLSourceStore.load().sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    private func registerKifuSourceURL(_ input: String) -> URLSourceStore.AddResult {
        let result = URLSourceStore.add(rawURL: input)
        if result.isSuccess {
            reloadRegisteredKifuSources()
            let host = registeredKifuSources.first?.hostLabel ?? "URL"
            statusMessage = "棋譜URLを登録しました（\(host)）"
        } else {
            switch result {
            case .empty:
                statusMessage = "URLを入力してください"
            case .invalidFormat:
                statusMessage = "有効なURLを入力してください"
            case .duplicate:
                statusMessage = "このURLはすでに登録済みです"
            case .unsupportedProvider:
                statusMessage = "将棋ウォーズのURLを入力してください"
            case .added:
                statusMessage = "棋譜URLを登録しました"
            }
        }
        return result
    }

    private func handleIncomingSharedURL(_ incomingURL: URL) {
        let result = URLSourceStore.addSharedShogiWarsURL(from: incomingURL)

        switch result {
        case .added, .duplicate:
            reloadRegisteredKifuSources()

            guard let raw = URLSourceStore.extractSharedURLString(from: incomingURL),
                  let normalized = URLSourceStore.normalizedURLString(from: raw),
                  let source = registeredKifuSources.first(where: {
                      $0.urlString.caseInsensitiveCompare(normalized) == .orderedSame
                  }) else {
                statusMessage = "将棋ウォーズURLを登録しました"
                return
            }

            Task {
                await importFromSharedSource(source)
            }

        case .invalidFormat:
            statusMessage = "共有URLの形式を認識できませんでした"
        case .unsupportedProvider:
            statusMessage = "将棋ウォーズのURLのみ取り込めます"
        case .empty:
            statusMessage = "共有されたURLが空です"
        }
    }

    @MainActor
    private func importFromSharedSource(_ source: RegisteredKifuSource) async {
        if backgroundKifuActor == nil {
            backgroundKifuActor = BackgroundKifuActor(modelContainer: modelContext.container)
        }
        guard let actor = backgroundKifuActor else {
            statusMessage = "インポートの初期化に失敗しました"
            return
        }

        statusMessage = "将棋ウォーズ棋譜を取得中..."
        do {
            let saveResult = try await KifuImporter.fetchAndSave(
                from: source.urlString,
                provider: source.provider,
                backgroundActor: actor
            )
            reloadSavedKifFiles()
            if saveResult.didInsert {
                statusMessage = "将棋ウォーズ棋譜を保存しました"
            } else {
                statusMessage = "この棋譜はすでに保存済みです"
            }
        } catch {
            statusMessage = KifuImporter.userFacingMessage(for: error)
        }
    }

    private func deleteRegisteredSource(_ source: RegisteredKifuSource) {
        URLSourceStore.remove(id: source.id)
        reloadRegisteredKifuSources()
        statusMessage = "登録URLを削除しました"
    }

    private func openKifuInViewer(_ entry: KifuViewerEntry) {
        switch entry {
        case .savedFile(let file):
            // ファイル後存在する場合はファイルから読み込み（一次）
            if let fileURL = file.fileURL {
                Task {
                    do {
                        let payload = try await Task.detached(priority: .userInitiated) {
                            let text = try KifStore.readText(at: fileURL)
                            return (try KifuCodec.decode(from: text), text)
                        }.value
                        presentRecordInViewer(payload.0, status: "保存した棋譜を検討モードで読み込みました", sourceText: payload.1)
                    } catch {
                        statusMessage = "KIF の読み込みに失敗しました: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
                    }
                }
            } else if let dbRecord = try? repository.fetch(id: file.id) {
                // DB専用レコード（URL導入分など）
                Task {
                    do {
                        let sourceText = dbRecord.kifText.isEmpty ? (dbRecord.rawKifText ?? "") : dbRecord.kifText
                        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            statusMessage = "KIF の読み込みに失敗しました: 棋譜テキストが空です"
                            return
                        }
                        let decoded = try await Task.detached(priority: .userInitiated) {
                            try KifuCodec.decode(from: sourceText)
                        }.value
                        presentRecordInViewer(decoded, status: "保存した棋譜を検討モードで読み込みました", sourceText: sourceText)
                    } catch {
                        statusMessage = "KIF の読み込みに失敗しました: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
                    }
                }
            } else {
                statusMessage = "KIF の読み込みに失敗しました"
            }

        case .registeredSource(let source):
            // KifuFetcher → KifuParser → presentRecordInViewer
            Task {
                statusMessage = "棋譜を取得中..."
                do {
                    let result = try await KifuImporter.fetch(from: source.urlString)
                    // 取得成功したら DB にも保存（重複はスキップ）
                    if let actor = backgroundKifuActor {
                        let kifText = KifuCodec.encode(result.record)
                        do {
                            _ = try await actor.upsert(
                                title:         result.title,
                                kifText:       kifText,
                                rawKifText:    result.rawText,
                                moveCount:     result.record.snapshot.moveRecords.count,
                                resultSummary: result.resultSummary,
                                provider:      source.provider,
                                sourceURL:     source.urlString,
                                createdAt:     result.record.savedAt
                            )
                        } catch {
                            statusMessage = "棋譜は取得しましたが、ライブラリ保存に失敗しました: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
                        }
                        reloadSavedKifFiles()
                    }
                    presentRecordInViewer(
                        result.record,
                        status: "棋譜を取得しました（\(result.playerSente) vs \(result.playerGote)）",
                        sourceText: result.rawText
                    )
                } catch {
                    statusMessage = KifuImporter.userFacingMessage(for: error)
                }
            }
        }
    }

    private func importKifuFile(from url: URL) {
        Task {
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let payload = try await Task.detached(priority: .userInitiated) {
                    let text = try KifStore.readText(at: url)
                    let parsed = try KifuParser.parse(text: text, includeHistory: false)
                    return (parsed, text)
                }.value

                presentRecordInViewer(
                    payload.0.record,
                    status: "棋譜ファイルを読み込みました（\(payload.0.playerSente) vs \(payload.0.playerGote)）",
                    sourceText: payload.1
                )
            } catch {
                statusMessage = "棋譜ファイルの読み込みに失敗しました"
            }
        }
    }

    @MainActor
    private func importKifuTextFromPaste(text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let message = "棋譜テキストを入力してください"
            statusMessage = message
            return message
        }

        // 極端に大きい貼り付けテキストはメモリ圧迫とフリーズの原因になるため事前に遮断
        let maxPasteLength = 2_000_000
        guard trimmed.count <= maxPasteLength else {
            let message = "貼り付けテキストが大きすぎます（上限約200万文字）"
            statusMessage = message
            return message
        }

        do {
            // 先にUI更新（ProgressView表示）を反映させる
            await Task.yield()
            let parsed = try await Task.detached(priority: .userInitiated) {
                try KifuParser.parse(text: trimmed, includeHistory: false)
            }.value
            presentRecordInViewer(
                parsed.record,
                status: "貼り付けた棋譜を読み込みました（\(parsed.playerSente) vs \(parsed.playerGote)）",
                sourceText: trimmed
            )
            return nil
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "棋譜テキストの解析に失敗しました"
            statusMessage = message
            return message
        }
    }

    private func decodeImportedKifuText(from data: Data) -> String? {
        KifStore.decodeText(from: data)
    }

    private func isValidSnapshotShape(_ snapshot: GameSnapshot) -> Bool {
        guard snapshot.board.count == 9 else { return false }
        return snapshot.board.allSatisfy { $0.count == 9 }
    }

    @MainActor
    private func presentRecordInViewer(_ record: PersistedGameRecord, status: String, sourceText: String? = nil) {
        guard !record.snapshot.board.isEmpty else {
            statusMessage = "棋譜局面データが破損しているため読み込めません"
            return
        }

        activateReviewMode(
            finalSnapshot: record.snapshot,
            history: record.moveHistory ?? [],
            sourceText: sourceText,
            status: status
        )
    }

    private func deleteSavedKif(at offsets: IndexSet) {
        for index in offsets {
            guard savedKifFiles.indices.contains(index) else { continue }
            let file = savedKifFiles[index]
            if let record = repositoryRecord(for: file) {
                try? repository.delete(record)
            }
            if let fileURL = file.fileURL {
                try? KifStore.removeItem(at: fileURL)
            }
        }
        reloadSavedKifFiles()
    }

    private func deleteSavedKif(_ file: SavedKifFile) {
        if let record = repositoryRecord(for: file) {
            try? repository.delete(record)
        }
        if let fileURL = file.fileURL {
            try? KifStore.removeItem(at: fileURL)
        }
        reloadSavedKifFiles()
    }

    private func moveKifToFolder(_ file: SavedKifFile, to folderName: String) {
        let normalizedFolder = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = normalizedKifTitle(file.fileName)
        var folderAssignments = loadFolderAssignments()

        do {
            // 同名レコードが複数存在するケースを考慮し、該当候補をまとめて更新
            let allRecords = (try? repository.fetchAll()) ?? []
            let targetRecords = allRecords.filter {
                $0.id == file.id || normalizedKifTitle($0.title) == normalizedTitle
            }

            if !targetRecords.isEmpty {
                for record in targetRecords {
                    try repository.updateFolder(record, to: normalizedFolder)
                    folderAssignments[folderAssignmentDBKey(record.id)] = normalizedFolder
                }
                if let fileURL = file.fileURL,
                   let baseDir = try? recordsDirectoryURL() {
                    let movedURL = try KifStore.moveItemToFolder(
                        originalURL: fileURL,
                        baseDirectoryURL: baseDir,
                        folderName: normalizedFolder
                    )
                    folderAssignments.removeValue(forKey: folderAssignmentFileKey(fileURL))
                    folderAssignments[folderAssignmentFileKey(movedURL)] = normalizedFolder
                }
                folderAssignments[folderAssignmentTitleKey(file.fileName)] = normalizedFolder
                saveFolderAssignments(folderAssignments)
                statusMessage = "「\(file.fileName)」を\(normalizedFolder.isEmpty ? "未分類" : normalizedFolder)に移動しました"
                reloadSavedKifFiles()
                return
            }

            // DB未登録のローカルファイルはここでDBへ取り込み後にフォルダを設定
            if let fileURL = file.fileURL {
                let text = try KifStore.readText(at: fileURL)
                let (moveCount, resultSummary) = KifuCodec.parseMetadata(from: text)

                if let existing = allRecords.first(where: {
                    normalizedKifTitle($0.title) == normalizedTitle
                }) {
                    try repository.updateFolder(existing, to: normalizedFolder)
                    folderAssignments[folderAssignmentDBKey(existing.id)] = normalizedFolder
                } else {
                    let newRecord = KifuRecord(
                        title: normalizedTitle,
                        kifText: text,
                        moveCount: moveCount,
                        resultSummary: resultSummary,
                        createdAt: file.savedAt,
                        folderName: normalizedFolder
                    )
                    try repository.insert(newRecord)
                }

                if let baseDir = try? recordsDirectoryURL() {
                    let movedURL = try KifStore.moveItemToFolder(
                        originalURL: fileURL,
                        baseDirectoryURL: baseDir,
                        folderName: normalizedFolder
                    )
                    folderAssignments.removeValue(forKey: folderAssignmentFileKey(fileURL))
                    folderAssignments[folderAssignmentFileKey(movedURL)] = normalizedFolder
                }
                folderAssignments[folderAssignmentTitleKey(file.fileName)] = normalizedFolder
                saveFolderAssignments(folderAssignments)

                statusMessage = "「\(file.fileName)」を\(normalizedFolder.isEmpty ? "未分類" : normalizedFolder)に移動しました"
            } else {
                statusMessage = "フォルダ移動に失敗しました"
            }
        } catch {
            statusMessage = "フォルダ移動に失敗しました"
        }

        reloadSavedKifFiles()
    }

    private func renameSavedKif(_ file: SavedKifFile, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "タイトルを入力してください"
            renameTargetFile = nil
            return
        }

        let invalidCharacters = CharacterSet(charactersIn: "/\\:?*\"<>|")
        let safeTitle = trimmed.components(separatedBy: invalidCharacters).joined(separator: "_")
        guard !safeTitle.isEmpty else {
            statusMessage = "使用できないタイトルです"
            renameTargetFile = nil
            return
        }

        var renamed = false
        if let record = repositoryRecord(for: file) {
            try? repository.rename(record, to: safeTitle)
            renamed = true
        }
        if let fileURL = file.fileURL {
            _ = try? KifStore.renameItem(originalURL: fileURL, safeTitle: safeTitle)
            renamed = true
        }
        statusMessage = renamed ? "タイトルを変更しました" : "タイトル変更に失敗しました"
        reloadSavedKifFiles()
        renameTargetFile = nil
    }

    private func undoLastMove() {
        guard moveHistory.count >= 2 else {
            statusMessage = "2手戻すには履歴が足りません"
            return
        }

        _ = moveHistory.popLast()
        guard let snapshot = moveHistory.popLast() else { return }

        apply(snapshot: snapshot)
        statusMessage = "待ったしました（2手戻し）。\(turn.label)の手番です"
    }

    private func resignCurrentPlayer() {
        resign(player: turn)
    }

    private func resign(player: Player) {
        guard !isGameOver() else { return }
        selected = nil
        selectedDropType = nil
        pendingPromotionMove = nil
        winner = player.opposite
        winReason = "投了"
        statusMessage = "\(player.label)が投了。\(player.opposite.label)の勝ちです"
    }

    private func interruptGame() {
        guard !isGameOver() else { return }
        selected = nil
        selectedDropType = nil
        pendingPromotionMove = nil
        isInterrupted = true
        statusMessage = "対局を中断しました"
    }

    private func advanceTurnAndUpdateStatus(movedBy player: Player, action: String) {
        let nextPlayer = player.opposite
        turn = nextPlayer

        if registerCurrentPositionAndDetectSennichite() {
            isSennichite = true
            statusMessage = "千日手（同一局面4回）で引き分けです"
            return
        }

        if isInCheck(player: nextPlayer, on: board) {
            if isCheckmate(player: nextPlayer) {
                winner = player
                winReason = "詰み"
                statusMessage = "王手詰み。\(player.label)の勝ちです"
            } else {
                statusMessage = "\(action) 王手！\(nextPlayer.label)の手番です"
            }
        } else {
            statusMessage = "\(action)。\(nextPlayer.label)の手番です"
        }
    }

    private func promotionState(for piece: Piece, from: Square, to: Square) -> (canPromote: Bool, mustPromote: Bool) {
        guard piece.type.canPromote, !piece.isPromoted else {
            return (false, false)
        }

        let inPromotionZoneFrom = GameEngine.isPromotionZone(row: from.row, owner: piece.owner)
        let inPromotionZoneTo = GameEngine.isPromotionZone(row: to.row, owner: piece.owner)
        let canPromote = inPromotionZoneFrom || inPromotionZoneTo

        let mustPromote: Bool
        switch piece.type {
        case .pawn, .lance:
            mustPromote = GameEngine.isDeadEndRow(to.row, owner: piece.owner)
        case .knight:
            mustPromote = GameEngine.isDeadEndKnightRow(to.row, owner: piece.owner)
        default:
            mustPromote = false
        }

        return (canPromote, mustPromote)
    }

    private func isLegalMove(from: Square, to: Square) -> Bool {
        canMovePiece(on: board, from: from, to: to)
    }

    private func canMovePiece(on boardState: [[Piece?]], from: Square, to: Square) -> Bool {
        guard
            GameEngine.isInside(from.row, from.col),
            GameEngine.isInside(to.row, to.col),
            let piece = boardState[from.row][from.col]
        else {
            return false
        }

        let dr = to.row - from.row
        let dc = to.col - from.col

        if dr == 0 && dc == 0 { return false }

        if let dest = boardState[to.row][to.col] {
            if dest.owner == piece.owner { return false }
        }

        let f = piece.owner.forward

        if piece.isPromoted {
            switch piece.type {
            case .pawn, .lance, .knight, .silver:
                return GameEngine.isGoldLikeMove(dr: dr, dc: dc, forward: f)
            case .bishop:
                let bishopMove = abs(dr) == abs(dc) && GameEngine.isPathClear(on: boardState, from: from, to: to)
                let kingOrthMove = (abs(dr) + abs(dc) == 1)
                return bishopMove || kingOrthMove
            case .rook:
                let rookMove = (dr == 0 || dc == 0) && GameEngine.isPathClear(on: boardState, from: from, to: to)
                let kingDiagMove = (abs(dr) == 1 && abs(dc) == 1)
                return rookMove || kingDiagMove
            case .king, .gold:
                break
            }
        }

        switch piece.type {
        case .king:
            return abs(dr) <= 1 && abs(dc) <= 1

        case .gold:
            return GameEngine.isGoldLikeMove(dr: dr, dc: dc, forward: f)

        case .silver:
            let moves = [(f, -1), (f, 0), (f, 1), (-f, -1), (-f, 1)]
            return moves.contains { $0.0 == dr && $0.1 == dc }

        case .knight:
            return dr == 2 * f && abs(dc) == 1

        case .pawn:
            return dr == f && dc == 0

        case .lance:
            guard dc == 0, dr.signum() == f.signum() else { return false }
            return GameEngine.isPathClear(on: boardState, from: from, to: to)

        case .rook:
            guard dr == 0 || dc == 0 else { return false }
            return GameEngine.isPathClear(on: boardState, from: from, to: to)

        case .bishop:
            guard abs(dr) == abs(dc) else { return false }
            return GameEngine.isPathClear(on: boardState, from: from, to: to)
        }
    }

    private func isLegalAfterMove(from: Square, to: Square, owner: Player, promote: Bool) -> Bool {
        guard canMovePiece(on: board, from: from, to: to) else { return false }
        guard let nextBoard = boardByApplyingMove(on: board, from: from, to: to, promote: promote) else { return false }
        return !isInCheck(player: owner, on: nextBoard)
    }

    private func boardByApplyingMove(on boardState: [[Piece?]], from: Square, to: Square, promote: Bool) -> [[Piece?]]? {
        guard var movingPiece = boardState[from.row][from.col] else { return nil }
        var next = boardState
        next[from.row][from.col] = nil
        if promote, movingPiece.type.canPromote {
            movingPiece.isPromoted = true
        }
        next[to.row][to.col] = movingPiece
        return next
    }

    private func boardByApplyingDrop(on boardState: [[Piece?]], type: PieceType, to: Square, owner: Player) -> [[Piece?]]? {
        guard boardState[to.row][to.col] == nil else { return nil }
        var next = boardState
        next[to.row][to.col] = Piece(owner: owner, type: type, isPromoted: false)
        return next
    }

    private func isInCheck(player: Player, on boardState: [[Piece?]]) -> Bool {
        guard let kingSquare = findKingSquare(of: player, on: boardState) else { return true }
        return isSquareAttacked(kingSquare, by: player.opposite, on: boardState)
    }

    private func findKingSquare(of player: Player, on boardState: [[Piece?]]) -> Square? {
        for row in 0..<9 {
            for col in 0..<9 {
                if let piece = boardState[row][col], piece.owner == player, piece.type == .king {
                    return Square(row: row, col: col)
                }
            }
        }
        return nil
    }

    private func isSquareAttacked(_ square: Square, by attacker: Player, on boardState: [[Piece?]]) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                guard let piece = boardState[row][col], piece.owner == attacker else { continue }
                if canMovePiece(on: boardState, from: Square(row: row, col: col), to: square) {
                    return true
                }
            }
        }
        return false
    }

    private func isCheckmate(player: Player) -> Bool {
        isCheckmate(player: player, on: board, senteHandState: senteHand, goteHandState: goteHand)
    }

    private func isCheckmate(player: Player, on boardState: [[Piece?]], senteHandState: [PieceType: Int], goteHandState: [PieceType: Int]) -> Bool {
        guard isInCheck(player: player, on: boardState) else { return false }
        return !hasAnyLegalEscape(for: player, on: boardState, senteHandState: senteHandState, goteHandState: goteHandState)
    }

    private func hasAnyLegalEscape(for player: Player, on boardState: [[Piece?]], senteHandState: [PieceType: Int], goteHandState: [PieceType: Int]) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                guard let piece = boardState[row][col], piece.owner == player else { continue }
                let from = Square(row: row, col: col)
                let targets = pseudoLegalTargets(for: piece, from: from, on: boardState)

                for to in targets {
                    guard canMovePiece(on: boardState, from: from, to: to) else { continue }

                    let promotion = promotionState(for: piece, from: from, to: to)

                    if promotion.mustPromote {
                        if let next = boardByApplyingMove(on: boardState, from: from, to: to, promote: true), !isInCheck(player: player, on: next) {
                            return true
                        }
                    } else if promotion.canPromote {
                        if let next = boardByApplyingMove(on: boardState, from: from, to: to, promote: false), !isInCheck(player: player, on: next) {
                            return true
                        }
                        if let next = boardByApplyingMove(on: boardState, from: from, to: to, promote: true), !isInCheck(player: player, on: next) {
                            return true
                        }
                    } else {
                        if let next = boardByApplyingMove(on: boardState, from: from, to: to, promote: false), !isInCheck(player: player, on: next) {
                            return true
                        }
                    }
                }
            }
        }

        let hand = player == .sente ? senteHandState : goteHandState
        var emptySquares: [Square] {
            var squares: [Square] = []
            squares.reserveCapacity(81)
            for row in 0..<9 {
                for col in 0..<9 where boardState[row][col] == nil {
                    squares.append(Square(row: row, col: col))
                }
            }
            return squares
        }

        for type in PieceType.handOrder {
            guard hand[type, default: 0] > 0 else { continue }

            for to in emptySquares {
                guard isLegalDrop(type: type, to: to, owner: player, on: boardState) else { continue }
                guard let next = boardByApplyingDrop(on: boardState, type: type, to: to, owner: player) else { continue }
                if !isInCheck(player: player, on: next) {
                    return true
                }
            }
        }

        return false
    }

    private func pseudoLegalTargets(for piece: Piece, from: Square, on boardState: [[Piece?]]) -> [Square] {
        var targets: [Square] = []

        func addStep(_ dr: Int, _ dc: Int) {
            let nr = from.row + dr
            let nc = from.col + dc
            guard GameEngine.isInside(nr, nc) else { return }
            if let dest = boardState[nr][nc], dest.owner == piece.owner {
                return
            }
            targets.append(Square(row: nr, col: nc))
        }

        func addRay(_ dr: Int, _ dc: Int) {
            var nr = from.row + dr
            var nc = from.col + dc

            while GameEngine.isInside(nr, nc) {
                if let dest = boardState[nr][nc] {
                    if dest.owner != piece.owner {
                        targets.append(Square(row: nr, col: nc))
                    }
                    return
                }
                targets.append(Square(row: nr, col: nc))
                nr += dr
                nc += dc
            }
        }

        let f = piece.owner.forward

        if piece.isPromoted {
            switch piece.type {
            case .pawn, .lance, .knight, .silver:
                addStep(f, -1)
                addStep(f, 0)
                addStep(f, 1)
                addStep(0, -1)
                addStep(0, 1)
                addStep(-f, 0)
                return targets
            case .bishop:
                addRay(1, 1)
                addRay(1, -1)
                addRay(-1, 1)
                addRay(-1, -1)
                addStep(1, 0)
                addStep(-1, 0)
                addStep(0, 1)
                addStep(0, -1)
                return targets
            case .rook:
                addRay(1, 0)
                addRay(-1, 0)
                addRay(0, 1)
                addRay(0, -1)
                addStep(1, 1)
                addStep(1, -1)
                addStep(-1, 1)
                addStep(-1, -1)
                return targets
            case .king, .gold:
                break
            }
        }

        switch piece.type {
        case .king:
            addStep(1, 1)
            addStep(1, 0)
            addStep(1, -1)
            addStep(0, 1)
            addStep(0, -1)
            addStep(-1, 1)
            addStep(-1, 0)
            addStep(-1, -1)
        case .gold:
            addStep(f, -1)
            addStep(f, 0)
            addStep(f, 1)
            addStep(0, -1)
            addStep(0, 1)
            addStep(-f, 0)
        case .silver:
            addStep(f, -1)
            addStep(f, 0)
            addStep(f, 1)
            addStep(-f, -1)
            addStep(-f, 1)
        case .knight:
            addStep(2 * f, -1)
            addStep(2 * f, 1)
        case .lance:
            addRay(f, 0)
        case .bishop:
            addRay(1, 1)
            addRay(1, -1)
            addRay(-1, 1)
            addRay(-1, -1)
        case .rook:
            addRay(1, 0)
            addRay(-1, 0)
            addRay(0, 1)
            addRay(0, -1)
        case .pawn:
            addStep(f, 0)
        }

        return targets
    }

    private func isLegalDrop(type: PieceType, to: Square, owner: Player, on boardState: [[Piece?]]? = nil) -> Bool {
        let currentBoard = boardState ?? board

        switch type {
        case .pawn:
            if GameEngine.isDeadEndRow(to.row, owner: owner) { return false }
            for row in 0..<9 {
                if let piece = currentBoard[row][to.col], piece.owner == owner, piece.type == .pawn, !piece.isPromoted {
                    return false
                }
            }
            return true
        case .lance:
            return !GameEngine.isDeadEndRow(to.row, owner: owner)
        case .knight:
            return !GameEngine.isDeadEndKnightRow(to.row, owner: owner)
        case .king, .gold, .silver, .bishop, .rook:
            return true
        }
    }

    private func handDict(for player: Player) -> [PieceType: Int] {
        player == .sente ? senteHand : goteHand
    }

    private func addToHand(owner: Player, type: PieceType) {
        if owner == .sente {
            senteHand[type, default: 0] += 1
        } else {
            goteHand[type, default: 0] += 1
        }
    }

    private func useFromHand(owner: Player, type: PieceType) {
        if owner == .sente {
            let newValue = max(0, senteHand[type, default: 0] - 1)
            if newValue == 0 {
                senteHand.removeValue(forKey: type)
            } else {
                senteHand[type] = newValue
            }
        } else {
            let newValue = max(0, goteHand[type, default: 0] - 1)
            if newValue == 0 {
                goteHand.removeValue(forKey: type)
            } else {
                goteHand[type] = newValue
            }
        }
    }

    private func registerCurrentPositionIfNeeded() {
        positionCounts = GameEngine.initializePositionCountsIfNeeded(
            counts: positionCounts,
            boardState: board,
            senteHandState: senteHand,
            goteHandState: goteHand,
            sideToMove: turn
        )
    }

    private func registerCurrentPositionAndDetectSennichite() -> Bool {
        let result = GameEngine.registerPositionAndDetectSennichite(
            counts: positionCounts,
            boardState: board,
            senteHandState: senteHand,
            goteHandState: goteHand,
            sideToMove: turn
        )
        positionCounts = result.counts
        return result.isSennichite
    }

    static func initialBoard(handicap: GameHandicap = .none) -> [[Piece?]] {
        var board = Array(repeating: Array(repeating: nil as Piece?, count: 9), count: 9)

        let backRow: [PieceType] = [.lance, .knight, .silver, .gold, .king, .gold, .silver, .knight, .lance]

        for col in 0..<9 {
            board[0][col] = Piece(owner: .gote, type: backRow[col])
            board[2][col] = Piece(owner: .gote, type: .pawn)
            board[6][col] = Piece(owner: .sente, type: .pawn)
            board[8][col] = Piece(owner: .sente, type: backRow[col])
        }

        board[1][1] = Piece(owner: .gote, type: .rook)
        board[1][7] = Piece(owner: .gote, type: .bishop)
        board[7][1] = Piece(owner: .sente, type: .bishop)
        board[7][7] = Piece(owner: .sente, type: .rook)

        switch handicap {
        case .none:
            break
        case .lance:
            board[8][8] = nil
        case .bishop:
            board[7][1] = nil
        case .rook:
            board[7][7] = nil
        case .twoPieces:
            board[7][7] = nil
            board[7][1] = nil
        case .fourPieces:
            board[7][7] = nil
            board[7][1] = nil
            board[8][0] = nil
            board[8][8] = nil
        case .sixPieces:
            board[7][7] = nil
            board[7][1] = nil
            board[8][0] = nil
            board[8][8] = nil
            board[8][1] = nil
            board[8][7] = nil
        }

        return board
    }
}

private struct SakuraPetalBackgroundView: View {
    @State private var phase: CGFloat = 0
    private let petalCount = 20

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<petalCount, id: \.self) { index in
                    let width = 9.0 + seeded(index, 10.3) * 7.0
                    let height = width * (1.25 + seeded(index, 11.7) * 0.5)
                    let speed = 0.18 + seeded(index, 12.9) * 0.30
                    let offsetX = seeded(index, 21.1) * proxy.size.width
                    let loopY = (phase * speed + seeded(index, 22.7)).truncatingRemainder(dividingBy: 1.25)
                    let y = (loopY - 0.15) * proxy.size.height
                    let drift = sin((phase * .pi * 2.0) + seeded(index, 31.4) * .pi * 2.0) * (8 + seeded(index, 34.8) * 16)
                    let rotation = Angle.degrees((phase * 360 * (0.30 + seeded(index, 15.4))) + seeded(index, 9.2) * 360)

                    SakuraPetalShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.80, blue: 0.88),
                                    Color(red: 0.85, green: 0.60, blue: 0.80)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: width, height: height)
                        .rotationEffect(rotation)
                        .position(x: offsetX + drift, y: y)
                        .shadow(color: Color(red: 0.85, green: 0.70, blue: 0.85).opacity(0.25), radius: 1.0, x: 0, y: 0)
                        .opacity(0.52 + seeded(index, 5.8) * 0.30)
                }
            }
            .drawingGroup(opaque: false)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func seeded(_ index: Int, _ salt: Double) -> CGFloat {
        let raw = sin(Double(index) * 12.9898 + salt) * 43758.5453123
        return CGFloat(raw - floor(raw))
    }
}

private struct SakuraPetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.55),
            control1: CGPoint(x: w * 0.87, y: h * 0.08),
            control2: CGPoint(x: w * 1.02, y: h * 0.34)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w * 0.95, y: h * 0.90),
            control2: CGPoint(x: w * 0.70, y: h)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.55),
            control1: CGPoint(x: w * 0.30, y: h),
            control2: CGPoint(x: w * 0.05, y: h * 0.90)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: -w * 0.02, y: h * 0.34),
            control2: CGPoint(x: w * 0.13, y: h * 0.08)
        )

        return path
    }
}

private extension View {
    @ViewBuilder
    func inlineNavigationBarTitleDisplayMode() -> some View {
        #if os(macOS)
        self
        #else
        self.navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    func kifExportShareSheet(
        item: Binding<KifExportShareItem?>,
        onDismiss: @escaping () -> Void
    ) -> some View {
        #if canImport(UIKit)
        self.sheet(item: item, onDismiss: onDismiss) { shareItem in
            KifExportActivitySheet(activityItems: [shareItem.url])
        }
        #else
        self
        #endif
    }
}

private struct KifExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

#if canImport(UIKit)
private struct KifExportActivitySheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private struct PreviewShellWorkaroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            content.accessibilityHidden(true)
        } else {
            content
        }
    }
}

#Preview {
    ContentView()
    .modelContainer(for: KifuRecord.self, inMemory: true)
        .modifier(PreviewShellWorkaroundModifier())
}
