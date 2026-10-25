# 毎日のコンテンツ更新（定期実行の Claude 向け手順書）

この手順書は、毎朝動く Claude の定期実行（Routine）が読むものです。人が手で同じことをしてもかまいません。

流れ:

1. Claude が Web 検索で候補を集める
2. `scripts/content/build_migration.py` が出典ページ・住所・作品画像を確かめ、通ったものだけを日時入りのマイグレーション（`supabase/migrations/<UTC日時>_content_<日付>.sql`）にする
3. Claude がブランチ `claude/content-<日付>` で PR を出す
4. CI（`.github/workflows/db.yml`）が、ローカルの DB でマイグレーションを試し、内容が「コンテンツの追加だけ」であることを確かめて自動でマージし、本番の DB に反映する

DB の鍵（service_role キーや DB のパスワード）は Claude に渡しません。本番に書き込むのは CI だけです。

## 0. 準備

1. リポジトリ `naki0227/encura` を用意する（なければ追加して clone する）。`main` から `claude/content-YYYYMMDD`（日本時間の日付）を作る。
2. Python の依存を入れる: `pip install -r scripts/requirements.txt`
3. 既に載せたものを確かめる: `python scripts/content/published.py`。ここに出ているものは候補に入れない。

## 1. 候補を集める

Web 検索で調べ、**自分で公式ページを開いて確かめたものだけ** を候補にします。記憶や推測で、展覧会・会期・作品の事実を作ってはいけません。迷ったら入れません。

### 展覧会（exhibitions）: 最大 15 件
- 日本国内で、今日開催中か、60 日以内に始まる美術展・博物館の企画展。地域が東京に偏らないようにする。
- `official_url` は主催館の公式ページ（展覧会のページが望ましい）。ニュースサイトやまとめサイトは不可。
- `title` と `venue` は公式表記のまま。`venue_address` は都道府県から書く（座標はスクリプトが住所から出す）。
- `summary` は公式ページに書いてあることだけで 100 字程度。

### 今日の一枚（daily_art）
- `published.py --kind "daily art"` の件数を見て、初回（10 件未満）は 20 点、それ以降は 4 点。
- 時代と地域（西洋、日本、東洋、近現代）が偏らないようにする。作者の没後 70 年以上たち、画像が自由に使える絵画・版画に限る。
- `title_en` と `artist_en` は Wikidata で引ける英語名（画像はこの名前で探す）。
- `content` は作品の背景と見どころを 200 字程度。作者・制作年・所蔵先などの事実は調べて確かめる。

### 美術ニュース（news）: 最大 5 件
- 過去 14 日間に日本語で報じられた美術の話題（大きな展覧会の発表、新発見・修復・返還、美術館の開館・リニューアル、作家の受賞など）。
- `source_url` はその話題を報じた記事か公式発表のページ。`subject` はそのページに載っている固有名詞（展覧会名・作品名・館名・作家名）。
- `content` は出典に書かれている事実だけで 200〜300 字。推測・誇張・出典のない数字は書かない。
- `keyword` は「展覧会」「新発見・修復」「美術館」「作品・作家」「特集」のどれか。
- 特定の作品が中心なら `artwork` に英語の作品名と作者名を入れる（画像が付く）。なければ `null`。

### 美術館（venues）: 任意
- 美術館を探す画面に出る館の一覧です。足りない地域の主要な美術館・博物館を、1 回に最大 10 館。
- `name` は公式表記、`address` は都道府県から、`website_url` は館名が載っている公式サイトのページ。
- 既に載っている館は `published.py --kind venue` で確かめて除く。

### 季節の特集（news に `keyword: "特集"` で入れる）
毎年恒例の展覧会は、**その年の会期が公式に発表されていれば** 特集記事にします。未発表なら書きません。

| 名前 | 時期 | 会場（例年） | 公式サイト |
| :--- | :--- | :--- | :--- |
| 正倉院展 | 10〜11 月 | 奈良国立博物館 | https://www.narahaku.go.jp/ |
| 日展 | 10〜12 月 | 国立新美術館 | https://nitten.or.jp/ |
| 院展 | 9 月 | 東京都美術館 | https://nihonbijutsuin.or.jp/ |
| 二科展 | 9 月 | 国立新美術館 | https://www.nika.or.jp/ |
| 博物館に初もうで | 1 月 | 東京国立博物館 | https://www.tnm.jp/ |

その月か翌月に当たるものだけを調べます。見出しは「【特集】YYYY年 ○○の見どころ」。

## 2. JSON にまとめてマイグレーションを作る

候補を作業用のファイル（リポジトリの外）に保存します。形は `scripts/content/sample_candidates.json` と同じです。

```bash
python scripts/content/build_migration.py /path/to/candidates.json
```

- 出力の「Accepted」「Rejected」を読む。Rejected が多いときは、出典 URL や英語名を直して一度だけやり直してよい。
- 何も通らなかった（終了コード 1）ときは、PR を出さずに終える。
- 作られたファイルは手で編集しない（CI が「スクリプトが作ったもの」であることを確かめます）。

## 3. PR を出す

- コミットするのは、新しく作られた `supabase/migrations/*_content_*.sql` **1 つだけ**。ほかのファイルを変えると自動マージされません。
- 確認: `python scripts/content/check_migration.py supabase/migrations/<作ったファイル>` が `OK` になること。
- ブランチ `claude/content-YYYYMMDD` に push し、PR を出す。タイトルは「コンテンツ YYYY-MM-DD」、本文は手順 2 の出力（Accepted / Rejected）。
- PR を出したら終わり。マージと本番への反映は CI が行う。CI が失敗したら、その内容を PR にコメントして終える（直すのは人が判断する）。

## 禁止事項

- `supabase/migrations` 以外のファイルの変更、既存のマイグレーションの編集・削除
- 推測で書いた展覧会・会期・事実、出典のない話題
- 人物の私生活や、特定の個人を取り上げる話題
