# EnCura 1.0.5 リリース手順（オーナー作業）

診断の一覧は [RECOVERY-2026-10.md](RECOVERY-2026-10.md) にあります。上から順に進めてください。
秘密情報（API キー、service_role キー）の値は、チャット・Issue・コミットに貼らないでください。

## 1. Supabase のプロジェクトを作る

旧プロジェクト「Encura」は復元できないため、会社のアカウントで新しく作ります。旧 DB の中身（自動生成の記事など）は引き継ぎません。

1. 会社の Supabase アカウントで新しいプロジェクトを作る（リージョンは Tokyo `ap-northeast-1`）。DB のパスワードは控えておく。
2. **Authentication → Sign In / Providers → Anonymous sign-ins** を有効にする（アプリは起動時に匿名サインインします。Edge Function の呼び出しにもこのセッションを使います）。
3. 次の値を控える（手順 4 で GitHub に登録します）。
   - Project URL と anon キー: **Project Settings → API**
   - Project ref: URL の `https://<ref>.supabase.co` の `<ref>`
   - DB の接続文字列: **Connect → Session pooler** の URI（`postgresql://postgres.<ref>:<パスワード>@...pooler.supabase.com:5432/postgres`）
   - アクセストークン: **Account → Access Tokens** で作る（Edge Function のデプロイ用）

テーブル・権限（RLS）・マップ用のストレージは、すべて `supabase/migrations/` のマイグレーションで作られます。手で SQL を流す必要はありません（手順 4 のあと、CI が自動で当てます）。

## 2. Gemini キーを発行して Edge Function に設定する

アプリは Gemini を直接呼びません。Edge Function `curator` がサーバー側のキーで呼びます。Gemini を使うのは、アプリ内のチャットと作品スキャン・マップ判定だけです（記事集めは毎日の Claude が行うので、Gemini を使いません）。

1. Google AI Studio で新しい API キーを発行する。
   - 流出したキーが無効になっていることも、同じ画面で確認してください。
   - 可能ならキーの API 制限を「Generative Language API」だけにします。
2. 新しいプロジェクトの **Edge Functions → Secrets** で `GEMINI_API_KEY` を追加する。
3. 必要ならモデルを変える: `GEMINI_MODEL`（カンマ区切りで先頭から試す。既定 `gemini-3.8-flash,gemini-3.6-flash`）。
4. 関数のデプロイは CI が行います（手順 4 の `SUPABASE_ACCESS_TOKEN` と `SUPABASE_PROJECT_REF` を登録すると、`main` に変更が入るたびに自動でデプロイ）。初回だけ **Actions → DB Migrations → Run workflow** を実行してください。

## 3. 使わなくなった Cloud Run のサービスを消す

写真の縮小・圧縮は、1.0.5 からアプリの中で行います。画像最適化サービス（Google Cloud Run の `encura`、europe-west1）は使わなくなりました。

アクセスがなければ料金はほぼかかりません。それでも、Google Cloud のコンソールで **Cloud Run → `encura` → 削除** をしておくと、料金がかかる余地がなくなります。サービスが 1 つだけのプロジェクトなら、課金の設定から外しても構いません。

## 4. GitHub の Secrets と Variables を設定する

DB への反映・ビルド・TestFlight・点検は、すべて GitHub Actions で動きます。
**Settings → Secrets and variables → Actions** に次を登録します。

| 種類 | 名前 | 中身 | 使う workflow |
| :--- | :--- | :--- | :--- |
| Secret | `SUPABASE_DB_URL` | 手順 1 の DB 接続文字列（パスワード入り） | DB Migrations |
| Secret | `SUPABASE_ACCESS_TOKEN` | 手順 1 のアクセストークン | DB Migrations（Edge Function のデプロイ） |
| Secret | `SUPABASE_PROJECT_REF` | 手順 1 の Project ref | DB Migrations（Edge Function のデプロイ） |
| Secret | `SUPABASE_URL` | Project URL | iOS リリース・点検 |
| Secret | `SUPABASE_ANON_KEY` | anon キー | iOS リリース・点検 |
| Secret | `GEMINI_API_KEY` | 手順 2 のキー（点検ではモデル一覧を見るだけで、料金はかかりません） | 点検 |
| Secret | `ASC_KEY_ID` | App Store Connect API キーの Key ID | iOS リリース |
| Secret | `ASC_ISSUER_ID` | 同じく Issuer ID | iOS リリース |
| Secret | `ASC_KEY_P8_BASE64` | `.p8` ファイルを base64 にしたもの（`base64 -i AuthKey_XXXX.p8 \| pbcopy`） | iOS リリース |
| Variable | `GEMINI_MODEL` | 任意。Edge Function と同じ値にする | 点検 |

登録したら **Actions → DB Migrations → Run workflow** を実行します。新しい DB にテーブルが作られ、Edge Function がデプロイされます。以後、`supabase/migrations/` に入ったマイグレーションは、`main` に入ったときに自動で本番に当たります（どこまで当てたかは DB の `supabase_migrations.schema_migrations` に日時つきで記録されます）。

App Store Connect API キーの作り方:
1. App Store Connect の **ユーザとアクセス → 統合 → App Store Connect API** でチームキーを作る。
2. 役割は **Admin** にする。署名証明書をクラウドで自動管理するため、App Manager では失敗することがあります。
3. `.p8` は一度しかダウンロードできません。base64 にして Secret に入れたら、元のファイルは安全な場所に保管してください。

## 5. 点検（Health Check）を動かす

`.github/workflows/health_check.yml` が毎朝 10:30（日本時間、その日のコンテンツが入ったあと）に次を確かめます。**Actions → Health Check → Run workflow** で手動でも動かせます。

| 点検 | 失敗したときに分かること |
| :--- | :--- |
| Gemini: key and models | キーが無効になった／設定したモデルが廃止された（いま使える Flash モデルを表示）。料金はかからない |
| Supabase: database and content | プロジェクトが止まった／今日の一枚・展覧会・ニュースが古い（毎日のコンテンツ更新が止まっている） |
| Supabase: content images | 表示中の画像が読み込めない |
| Edge Function: curator | アプリと同じ経路（匿名サインイン → 関数）で AI 学芸員が答えるか（1 日 1 回、短い質問を 1 つ送る） |

- どれかが失敗すると workflow が赤になり、「Health check failed」という Issue を作ります（開いたままなら日付つきでコメントを足します）。
- 点検のスケジュールが「60 日無更新での自動停止」にかからないよう、毎回有効にし直します。
- 点検は毎回、匿名ユーザーを 1 人作ります（アプリの起動と同じ動き）。
- モデル廃止の警告が出たら、Variable `GEMINI_MODEL` と Edge Function のシークレット `GEMINI_MODEL` を、表示された新しいモデルに変えます。

## 6. 毎日のコンテンツ更新を始める

展覧会・今日の一枚・美術ニュースは、毎朝 Claude の定期実行（Routine）が集めます。手順は [CONTENT_ROUTINE.md](CONTENT_ROUTINE.md) です。

1. Claude が Web 検索で候補を集め、`scripts/content/build_migration.py` が出典ページ・住所・作品画像を確かめて、通ったものだけを `supabase/migrations/<UTC日時>_content_<日付>.sql` にする
2. Claude がブランチ `claude/content-<日付>` で PR を出す
3. CI がローカルの DB で試し、中身が「コンテンツの追加だけ」なら自動でマージして本番に当てる

DB の鍵は Claude に渡しません。Routine の作成は、手順 1〜4 が終わったら Claude に頼んでください。初回は今日の一枚を 20 点まとめて入れ、以後は毎日少しずつ足します。

## 6.5 画集のリンク（Amazon アソシエイト、任意）

「学ぶ」の画家・流派・作品のページに「画集を探す」ボタンを出せます。ボタンは Amazon の検索結果を開き、アソシエイトのタグ付きで購入されると紹介料が入ります。

1. Amazon アソシエイト・プログラム（https://affiliate.amazon.co.jp/）に登録し、トラッキング ID（例: `encura-22`）を取る。審査には、アプリの App Store の URL が要ります。
2. GitHub の **Settings → Secrets and variables → Actions → Variables** に `AMAZON_ASSOCIATE_TAG` を作り、トラッキング ID を入れる（秘密ではないので Secrets ではなく Variables）。
3. 次の TestFlight ビルドから、ボタンと「Amazonのアソシエイトとして、EnCuraは適格販売により収入を得ています。」の表示が出る。値が空ならボタンは出ない。

## 7. TestFlight に上げる

1. 手順 1〜4 が済んでいることを確認する。
2. **Actions → iOS Release (TestFlight) → Run workflow** を実行する。
   - `build_number` は空なら `pubspec.yaml` の値（今回は 14。7〜13 は 2026-10-26〜27 にアップロード済み）。同じ番号は二度上げられないので、作り直すときは 8, 9… を入れる。
   - `v1.0.5` のようなタグを push しても動きます。
   - 初回は GitHub の Environment「release」が自動で作られます。承認者を付けたい場合は **Settings → Environments → release** で設定します。
3. 15〜30 分ほどで、App Store Connect の TestFlight にビルドが出ます。輸出コンプライアンスは Info.plist で「該当なし（HTTPS のみ）」と申告済みなので、そのままテスターに配れます。
4. TestFlight で実機確認する。
   - ホームに今日の一枚・トレンドが出る
   - 学ぶタブで年表・作品ライブラリが開き、♡ を付けると「あなたへのおすすめ」が出る
   - 学ぶタブの「画家から見る」から画家のページが開き、作品・流れ・展覧会・同じ時代の画家へ行き来できる
   - 作品当てクイズが最後まで遊べる
   - ホーム画面とロック画面に「今日の一枚」ウィジェットを置ける
   - 学芸員タブで質問すると日本語で答える
   - カメラで作品を撮ると解説が返る
   - 会場詳細でマップを撮ると「マップを投稿しました」になる
   - 展覧会詳細の地図ボタンが正しい場所を開く

手元の Mac でビルドする場合は `scripts/ios/archive.sh config/prod.json build` を使えます（API キーの環境変数がなければ、署名なしのアーカイブだけを作ります）。

## 8. App Store Connect で審査に提出する（手作業）

1. 新しいバージョン **1.0.5** を作り、TestFlight で確認したビルドを選ぶ。
2. App 情報を直す。
   - サポート URL・マーケティング URL: `https://enludus.vercel.app` → `https://enludus.com`
   - プライバシーポリシー URL: `https://enludus.com/products/encura-privacy`（naki0227/company-web#22 をマージして公開されてから設定する。アプリ内のリンクもこのページに変えた）
   - 連絡先: contact@enludus.com
3. 「App のプライバシー」の回答が変わらないか確認する（送るデータの種類は 1.04 と同じで、経路にサーバーが加わっただけ）。
4. 「このバージョンの最新情報」に下のリリースノートを入れ、審査に提出する。

## リリースノート案（1.0.5）

```
新しい「学ぶ」タブとウィジェットを追加し、不具合を修正しました

・「学ぶ」タブ：印象派から現代美術、浮世絵や琳派まで、美術の流れを年表とつながりで読めるようになりました。パブリックドメインの名作を解説つきで見られる作品ライブラリも加わりました。
・画家のページ：生涯と作品をまとめて見られ、流派や同じ時代の画家、その画家に会える展覧会（開催中・これから・終了）へもたどれます。
・「この絵は誰の作品？」：作品当てクイズで、描き方の違いを楽しく覚えられます。
・気に入った作品に ♡ を付けると、好みに合わせたおすすめを表示します。
・ホーム画面とロック画面に「今日の一枚」ウィジェットを置けるようになりました。
・展覧会を現在地から近い順に並べられるようになりました。
・画面全体のデザインを見直し、ニュースや作品の解説を読みやすくしました。
・AI学芸員（チャット）と作品スキャンが応答しなくなっていた問題を修正しました。
・会場マップの投稿で、AIによる判定が失敗する問題を修正しました。
・展覧会・ニュースは、公式サイトなどの出典で確認できたものだけを載せるようにしました。
・作品やニュースの画像が表示されないことがある問題を修正しました。

ご不便をおかけし申し訳ありませんでした。ご意見・不具合のご報告は contact@enludus.com までお寄せください。
```
