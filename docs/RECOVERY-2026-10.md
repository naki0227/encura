# EnCura 復旧診断（2026-10-20）

App Store 公開版 1.04（2025-12-18 公開）が正常に動かなくなっている原因の一覧です。
オーナー作業の手順は [RELEASE.md](RELEASE.md) にあります。

## 調べたこと

| 対象 | 方法 | 結果 |
| :--- | :--- | :--- |
| 公開版 | `itunes.apple.com/lookup?bundleId=com.enludus.encura&country=jp` | 1.04 / 最低 iOS 13.0 / 販売元 URL が `https://enludus.vercel.app` のまま |
| Supabase | プロジェクト一覧 | プロジェクト「Encura」が **INACTIVE（一時停止）** |
| Rust 画像最適化（Cloud Run） | `POST /process` に JPEG を送信 | **200 で HTML「Placeholder \| Cloud Run」を返す**（サービスが置き換わっている） |
| Gemini | コード・設定・Google の公開情報 | アプリは `.env` を asset として同梱しキーを埋め込み。マップ判定のモデル `gemini-2.0-flash-exp` は廃止済み |
| GitHub Actions | ワークフロー一覧・実行履歴 | 日次クローラーと週次モニターが 2026-03-15 から **disabled_inactivity**（60 日無更新で自動停止） |
| ビルド（修正前） | Flutter 3.47.7 / Dart 3.13.5 で `flutter analyze`・`flutter test` | analyze: 警告 3 件（`flutter_lints` 未導入ほか）。test: テンプレのカウンターテストのままで失敗 |
| Rust サービスのビルド（修正前） | `cargo build` | `serde_json` 未宣言でコンパイル不可。依存の最低 Rust が 1.89 なのに Dockerfile は 1.83 |
| 利用規約・プライバシー（Notion） | HTTP | 200。中身は JS 描画のため未確認 |
| `https://enludus.com` | HTTP / sitemap | 200。EnCura 用のページはまだない（`/privacy` はサイト全体のもの） |

## 壊れているところ

状態の凡例: **直した** = このブランチのコードで解決 / **オーナー作業** = 手順どおりの作業が必要

| # | 症状 | 原因 | 直し方 | 状態 |
| :- | :--- | :--- | :--- | :--- |
| 1 | 起動はするが、ホーム・展覧会・アーカイブが空、地図投稿もできない | Supabase プロジェクトが一時停止。DB・認証・Storage がすべて止まっている | プロジェクトを復元（または新規作成して SQL を流す）。匿名サインインを有効にする | オーナー作業（RELEASE.md 手順 1） |
| 2 | AI 学芸員のチャットが「Error: …」になる | Gemini キーを `.env` ごとアプリに同梱していた。そのキーは流出のため無効化済み | Gemini 呼び出しを Edge Function `curator` に移し、キーはサーバーのシークレットだけに置く。アプリから `.env` 同梱と `google_generative_ai`・`flutter_dotenv` を削除 | 直した（コード）＋ オーナー作業（新キー設定とデプロイ、手順 2） |
| 3 | Scan & Guide（カメラ解説）が失敗する | 最適化サービスが HTML を 200 で返し、アプリはそれを JPEG として Gemini に送っていた | 応答が `image/*` のときだけ採用し、それ以外は元画像で続行。タイムアウト 15 秒。撮影画像を 2048px・品質 90 に制限して、フォールバック時も送れる大きさにする | 直した |
| 4 | マップ投稿の AI 判定が必ず失敗する | `gemini-2.0-flash-exp` は廃止済み。キーも無効 | 判定を Edge Function に移し、既定モデルを `gemini-3.8-flash` にする（`GEMINI_MODEL` で変更可） | 直した（デプロイは手順 2） |
| 5 | 画像最適化が効かない | Cloud Run サービスが置き換わっている。さらにソースがそのままではビルドできない | `serde_json` を追加し、Dockerfile の Rust を 1.97 にする。`Cargo.lock` をコミット。ローカルでビルドし、2000×1500 → 1024×768 の JPEG が返ることを確認 | 直した（コード）＋ オーナー作業（再デプロイ、手順 3）。再デプロイまでは #3 の対応で元画像のまま動く |
| 6 | 展覧会・今日の一枚・トレンドが 3 月から更新されない | スケジュール実行が無更新で自動停止。Supabase も停止中。GitHub の `GEMINI_API_KEY` も無効の可能性が高い | クローラーのモデルを `GEMINI_MODEL`（既定 `gemini-3.8-flash`）で変えられるようにする。配信モニターの YouTube 検索は `YOUTUBE_API_KEY` を優先する（AI Studio の Gemini キーは通常 YouTube Data API に使えない） | 直した（コード）＋ オーナー作業（シークレット更新とワークフロー再有効化、手順 4） |
| 7 | `flutter analyze` 警告・`flutter test` 失敗 | `flutter_lints` 未導入、`intl` が暗黙の依存、未使用変数、テンプレのテスト | 依存を追加して警告を解消。テストを実際の処理に合わせて書き直す（7 件） | 直した |
| 8 | CI が何も検査していない | `ci.yml` が echo だけ | analyze・test・Edge Function の `deno check`/`deno lint`・Rust ビルド・未署名の iOS ビルドを実行 | 直した |
| 9 | App Store の販売元 URL が旧サイト | `https://enludus.vercel.app` のまま | App Store Connect でサポート URL・マーケティング URL を `https://enludus.com` に変更 | オーナー作業（手順 6） |
| 10 | 利用規約・プライバシーポリシーのリンク先が確認できない | Notion の公開ページ（中身は JS 描画で自動確認できない） | ブラウザで公開状態と内容を確認。AI 処理がサーバー経由になったことを反映するか判断 | オーナー作業（手順 6） |

## 埋め込みキーの確認

- 修正後のアプリには、Gemini のキーも `.env` も入りません。アプリが持つのは Supabase の URL と anon キー（公開前提のキーで、RLS で守る）と最適化サービスの URL だけで、どれもビルド時に `--dart-define` で渡します。
- リポジトリと履歴（取得した範囲）に `AIza…` 形式のキーはありません。`.env` がコミットされた形跡もありません。
- 公開中の 1.04 のバイナリには無効化済みのキーが入っています。キーは無効なので悪用はできませんが、1.0.5 の公開後は 1.04 を配信し続ける理由はありません。

## そのままにしたもの（今回の範囲外）

- `flutter_markdown` は提供終了（後継は `flutter_markdown_plus`）。今のところビルド・動作に問題はありません。
- `venue_maps` テーブルと Storage は匿名でも INSERT できるポリシーのまま（以前からの設計）。
- Python クローラーの `google-generativeai` SDK は提供終了済み。同じ REST API を使うので当面は動く見込みですが、動かなくなった場合は `google-genai` に移します。
