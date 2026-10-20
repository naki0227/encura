# EnCura 1.0.5 リリース手順（オーナー作業）

診断の一覧は [RECOVERY-2026-10.md](RECOVERY-2026-10.md) にあります。上から順に進めてください。
秘密情報（API キー、service_role キー）の値は、チャット・Issue・コミットに貼らないでください。

## 1. Supabase を動かす

プロジェクト「Encura」（リージョン ap-northeast-1）は一時停止中です。

1. Supabase ダッシュボードで「Encura」を開き、**Restore project** を押す。
   - 無料プランで同時に動かせるプロジェクトは 2 つまでです。いま別の 2 つが動いているので、どれかを止めるか、プランを上げる必要があります。
   - 停止から 90 日を過ぎていると、ダッシュボードから復元できないことがあります。その場合は停止中のプロジェクトのバックアップをダウンロードし、新しいプロジェクトを作って取り込みます。新しいプロジェクトにした場合は、`supabase/` の SQL（`schema.sql` → `refactor_venues.sql` → `setup_venue_maps.sql` → `setup_daily_columns.sql` → `setup_trending_articles.sql` → `add_affiliate_url.sql`）を流し、URL と anon キーが変わる点に注意してください（手順 4 の Secrets に入れます）。
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
3. 必要ならモデルを変える: `GEMINI_MODEL`（カンマ区切りで先頭から試す。既定 `gemini-3.8-flash,gemini-3.6-flash`）。
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
URL が変わった場合は、手順 4 の Variable `IMAGE_OPTIMIZER_URL` に新しい URL を入れます。

## 4. GitHub の Secrets と Variables を設定する

ビルド・TestFlight・クローラー・点検は、すべて GitHub Actions で動きます。
**Settings → Secrets and variables → Actions** に次を登録します。

| 種類 | 名前 | 中身 | 使う workflow |
| :--- | :--- | :--- | :--- |
| Secret | `GEMINI_API_KEY` | 手順 2 のキー（別のキーでもよい） | クローラー・点検 |
| Secret | `SUPABASE_URL` | Supabase の URL | 全部 |
| Secret | `SUPABASE_ANON_KEY` | Supabase の anon キー | iOS リリース・点検 |
| Secret | `SUPABASE_SERVICE_ROLE_KEY` | service_role キー（書き込み用。アプリには入れない） | クローラー |
| Secret | `ASC_KEY_ID` | App Store Connect API キーの Key ID | iOS リリース |
| Secret | `ASC_ISSUER_ID` | 同じく Issuer ID | iOS リリース |
| Secret | `ASC_KEY_P8_BASE64` | `.p8` ファイルを base64 にしたもの（`base64 -i AuthKey_XXXX.p8 \| pbcopy`） | iOS リリース |
| Variable | `GEMINI_MODEL` | 任意。カンマ区切りで先頭から試す（例 `gemini-3.8-flash,gemini-3.6-flash`） | クローラー・点検 |
| Variable | `IMAGE_OPTIMIZER_URL` | 任意。最適化サービスの `/process`。未設定ならアプリの既定値 | iOS リリース・点検 |

App Store Connect API キーの作り方:
1. App Store Connect の **ユーザとアクセス → 統合 → App Store Connect API** でチームキーを作る。
2. 役割は **Admin** にする。署名証明書をクラウドで自動管理するため、App Manager では失敗することがあります。
3. `.p8` は一度しかダウンロードできません。base64 にして Secret に入れたら、元のファイルは安全な場所に保管してください。

## 5. 点検（Health Check）を動かす

`.github/workflows/health_check.yml` が毎朝 8:30（日本時間）に次を確かめます。**Actions → Health Check → Run workflow** で手動でも動かせます。

| 点検 | 失敗したときに分かること |
| :--- | :--- |
| Gemini: key and models | キーが無効になった／設定したモデルが廃止された（いま使える Flash モデルを表示） |
| Gemini: generate | 生成が通らない |
| Gemini: search grounding | Google 検索連携が使えない（クローラーが内容を確認できなくなる） |
| Supabase: database and content | プロジェクトが止まった／今日の一枚・展覧会・ニュースが古い |
| Supabase: content images | 表示中の画像が読み込めない（`fix_image_urls.py` を実行する） |
| Edge Function: curator | アプリと同じ経路（匿名サインイン → 関数）で AI 学芸員が答えるか |
| Image optimizer | 最適化サービスが画像を返すか（止まっていても警告だけ。アプリは元画像で動く） |

- どれかが失敗すると workflow が赤になり、「Health check failed」という Issue を作ります（開いたままなら日付つきでコメントを足します）。
- 同じ workflow が、クローラーと点検自身のスケジュールを毎回有効にし直します。3 月に起きた「60 日無更新での自動停止」を防ぐためです。
- 点検は毎回、匿名ユーザーを 1 人作ります（アプリの起動と同じ動き）。
- モデル廃止の警告が出たら、Variable `GEMINI_MODEL` と Edge Function のシークレット `GEMINI_MODEL` を、表示された新しいモデルに変えます。

## 6. クローラーを動かす

1. **Actions → Daily Art Crawler** を **Enable workflow** にする（2026-03-15 から自動停止中。点検が一度動けば、以後は自動で有効に保たれます）。
2. **Run workflow** で `dry_run` にチェックを入れて実行し、ログに「確認できた展覧会・記事」が出ることを見る（DB には書かない）。
3. 問題なければ `dry_run` なしで実行する。以後は毎朝 9:00 に動きます。
4. 既存の会場の座標はモデルが書いたもので、ずれています。一度だけ手元で直してください。

   ```bash
   pip install -r scripts/requirements.txt
   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... python scripts/seed_venues.py --relocate
   ```
5. 保存済みの画像 URL を直す（Wikimedia の配信幅の変更と、存在しない画像への対応）。まず確認だけをして、内容がよければ `--apply` で書き込みます。

   ```bash
   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... python scripts/fix_image_urls.py
   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... python scripts/fix_image_urls.py --apply
   ```

## 7. TestFlight に上げる

1. 手順 1〜4 が済んでいることを確認する。
2. **Actions → iOS Release (TestFlight) → Run workflow** を実行する。
   - `build_number` は空なら `pubspec.yaml` の値（今回は 7）。同じ番号は二度上げられないので、作り直すときは 8, 9… を入れる。
   - `v1.0.5` のようなタグを push しても動きます。
   - 初回は GitHub の Environment「release」が自動で作られます。承認者を付けたい場合は **Settings → Environments → release** で設定します。
3. 15〜30 分ほどで、App Store Connect の TestFlight にビルドが出ます。輸出コンプライアンスは Info.plist で「該当なし（HTTPS のみ）」と申告済みなので、そのままテスターに配れます。
4. TestFlight で実機確認する。
   - ホームに今日の一枚・トレンドが出る
   - Curator タブで質問すると日本語で答える
   - カメラで作品を撮ると解説が返る
   - 会場詳細でマップを撮ると「Map verified and uploaded!」になる
   - 展覧会詳細の地図ボタンが正しい場所を開く

手元の Mac でビルドする場合は `scripts/ios/archive.sh config/prod.json build` を使えます（API キーの環境変数がなければ、署名なしのアーカイブだけを作ります）。

## 8. App Store Connect で審査に提出する（手作業）

1. 新しいバージョン **1.0.5** を作り、TestFlight で確認したビルドを選ぶ。
2. App 情報を直す。
   - サポート URL・マーケティング URL: `https://enludus.vercel.app` → `https://enludus.com`
   - プライバシーポリシー URL: アプリ内と同じ Notion ページが公開状態か、ブラウザで確認する。チャット・画像が Supabase（Edge Function）経由で Google の AI に送られることが書かれているかも確認する
   - 連絡先: contact@enludus.com
3. 「App のプライバシー」の回答が変わらないか確認する（送るデータの種類は 1.04 と同じで、経路にサーバーが加わっただけ）。
4. 「このバージョンの最新情報」に下のリリースノートを入れ、審査に提出する。

## リリースノート案（1.0.5）

```
不具合の修正とAI機能の復旧

・AI学芸員（チャット）と作品スキャンが応答しなくなっていた問題を修正しました。
・会場マップの投稿で、AIによる判定が失敗する問題を修正しました。
・画像処理サーバーにつながらないときも、作品スキャンを続けられるようにしました。
・展覧会・ニュースは、公式サイトなどの出典で確認できたものだけを載せるようにしました。
・展覧会の地図ボタンが正しい会場を開かないことがある問題を修正しました。
・作品やニュースの画像が表示されないことがある問題を修正しました。
・AIとの通信をサーバー経由にし、安全性を高めました。

ご不便をおかけし申し訳ありませんでした。ご意見・不具合のご報告は contact@enludus.com までお寄せください。
```
