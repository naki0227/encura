# EnCura 1.0.5 リリース手順（オーナー作業）

診断の一覧は [RECOVERY-2026-10.md](RECOVERY-2026-10.md) にあります。上から順に進めてください。
秘密情報（API キー、service_role キー）の値は、チャット・Issue・コミットに貼らないでください。

## 1. Supabase を動かす

プロジェクト「Encura」（リージョン ap-northeast-1）は一時停止中です。

1. Supabase ダッシュボードで「Encura」を開き、**Restore project** を押す。
   - 無料プランで同時に動かせるプロジェクトは 2 つまでです。いま別の 2 つが動いているので、どれかを止めるか、プランを上げる必要があります。
   - 停止から 90 日を過ぎていると、ダッシュボードから復元できないことがあります。その場合は停止中のプロジェクトのバックアップをダウンロードし、新しいプロジェクトを作って取り込みます。新しいプロジェクトにした場合は、`supabase/` の SQL（`schema.sql` → `refactor_venues.sql` → `setup_venue_maps.sql` → `setup_daily_columns.sql` → `setup_trending_articles.sql` → `add_affiliate_url.sql`）を流し、URL と anon キーが変わる点に注意してください（手順 5 の設定ファイルに入れます）。
2. **Authentication → Sign In / Providers → Anonymous sign-ins** を有効にする（アプリは起動時に匿名サインインします。Edge Function の呼び出しにもこのセッションを使います）。
3. Storage にバケット `venue_maps`（公開）があることを確認する。

## 2. Gemini キーを発行し、Edge Function をデプロイする

アプリは Gemini を直接呼びません。Edge Function `curator` がサーバー側のキーで呼びます。

1. Google AI Studio で新しい API キーを発行する。
   - 流出したキーが無効になっていることも、同じ画面で確認してください。
   - 可能ならキーの API 制限を「Generative Language API」だけにします。
2. キーをシークレットに入れる。どちらか一方でかまいません。
   - ダッシュボード: **Edge Functions → Secrets** で `GEMINI_API_KEY` を追加
   - CLI: シェル履歴に残らないよう、git 管理外のファイルから読み込む

     ```bash
     supabase link --project-ref <project-ref>
     # supabase/.env.local に GEMINI_API_KEY=... を書く（コミットしない）
     supabase secrets set --env-file supabase/.env.local
     ```
3. 必要ならモデルを変える: `GEMINI_MODEL`（既定 `gemini-3.8-flash`）。
4. デプロイする（JWT 検証は既定のまま有効にしておく）。

   ```bash
   supabase functions deploy curator
   ```
5. 動作確認: ダッシュボードの **Edge Functions → curator → Logs** に、アプリからの呼び出し後もエラーが出ていないこと。

## 3. 画像最適化サービス（Cloud Run）を再デプロイする

いまの URL は Cloud Run のプレースホルダーを返しています。アプリは画像以外の応答を無視して元画像で続行するので、この手順をしなくても Scan & Guide は動きます。

```bash
gcloud run deploy encura \
  --source image_optimizer \
  --region europe-west1 \
  --allow-unauthenticated
```

確認: `curl -F image=@sample.jpg https://<service-url>/process -o out.jpg` で `image/jpeg` が返ること。
URL が変わった場合は、手順 5 の `IMAGE_OPTIMIZER_URL` に新しい URL を入れます。サービスを使わない場合は空文字にします。

## 4. GitHub Actions（クローラー）を戻す

1. リポジトリの **Settings → Secrets and variables → Actions** で次を更新する。
   - `GEMINI_API_KEY`: 手順 2 で発行したキー（別のキーにしてもよい）
   - `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY`: 新しいプロジェクトにした場合だけ更新する
   - `YOUTUBE_API_KEY`（任意）: 週次の配信モニター用。未設定なら `GEMINI_API_KEY` を使うが、AI Studio のキーでは YouTube Data API が通らないことが多い
   - 変数 `GEMINI_MODEL`（任意）: クローラーのモデルを変えるとき
2. **Actions** タブで「Daily Art Crawler」と「Weekly Stream Monitor」を **Enable workflow** にする（2026-03-15 から無更新で自動停止中）。
3. 「Daily Art Crawler」を **Run workflow** で手動実行し、成功することを確認する。

## 5. iOS ビルドを作る

1. 設定ファイルを作る（`config/*.json` は git 管理外）。

   ```bash
   cp config/prod.example.json config/prod.json
   # SUPABASE_URL / SUPABASE_ANON_KEY / IMAGE_OPTIMIZER_URL を埋める
   ```
2. 最新の Xcode が入った Mac でビルドする（CI は Flutter 3.47.7 で確認済み）。

   ```bash
   flutter pub get
   flutter build ipa --release --dart-define-from-file=config/prod.json
   ```
3. 実機で確認する。
   - ホームに今日の一枚・トレンドが出る
   - Curator タブで質問すると日本語で答える
   - カメラで作品を撮ると解説が返る
   - 会場詳細でマップを撮ると「Map verified and uploaded!」になる
4. `build/ios/ipa/*.ipa` を Transporter か Xcode Organizer でアップロードする。

## 6. App Store Connect で提出する

1. 新しいバージョン **1.0.5** を作り、手順 5 のビルド（1.0.5 (7)）を選ぶ。
2. App 情報を直す。
   - サポート URL・マーケティング URL: `https://enludus.vercel.app` → `https://enludus.com`
   - プライバシーポリシー URL: アプリ内と同じ Notion ページが公開状態か、ブラウザで確認する。チャット・画像が Supabase（Edge Function）経由で Google の AI に送られることが書かれているか確認する
   - 連絡先: contact@enludus.com
3. 「App のプライバシー」の回答が変わらないか確認する（送るデータの種類は 1.04 と同じで、経路にサーバーが加わっただけ）。
4. 「このバージョンの最新情報」に下のリリースノートを入れ、審査に提出する。

## リリースノート案（1.0.5）

```
不具合の修正とAI機能の復旧

・AI学芸員（チャット）と作品スキャンが応答しなくなっていた問題を修正しました。
・会場マップの投稿で、AIによる判定が失敗する問題を修正しました。
・画像処理サーバーにつながらないときも、作品スキャンを続けられるようにしました。
・AIとの通信をサーバー経由にし、安全性を高めました。

ご不便をおかけし申し訳ありませんでした。ご意見・不具合のご報告は contact@enludus.com までお寄せください。
```
