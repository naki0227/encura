import datetime as dt
import json
from pathlib import Path

from content import build_migration as bm
from content import check_migration as cm

NOW = dt.datetime(2026, 10, 25, 0, 0, tzinfo=dt.timezone.utc)
SAMPLE = json.loads((Path(bm.__file__).parent / "sample_candidates.json").read_text(encoding="utf-8"))


class FakeChecks(bm.Checks):
    def __init__(self, pages=None, images=None, coords=None):
        super().__init__()
        self.pages = pages or {}
        self.images = images or {}
        self.coords = coords

    def page_naming(self, phrase, urls):
        return next((u for u in urls if phrase in self.pages.get(u, "")), None)

    def geocode(self, address):
        return self.coords

    def artwork_image(self, titles, artists):
        return next((self.images[t] for t in titles if t in self.images), None)


def checks_for_sample():
    return FakeChecks(
        pages={
            "https://www.tnm.jp/": "東京国立博物館 特別展「例示の美術」",
            "https://example.com/article": "出典に載っている固有名詞",
            "https://ja.wikipedia.org/wiki/写実主義": "写実主義",
            "https://ja.wikipedia.org/wiki/印象派": "印象派",
        },
        images={
            "The Starry Night": "https://upload.wikimedia.org/starry.jpg",
            "Impression, Sunrise": "https://upload.wikimedia.org/sunrise.jpg",
        },
        coords=(35.717556, 139.775543),
    )


def test_sample_produces_a_migration_that_passes_the_gate(tmp_path):
    body, report = bm.build(SAMPLE, NOW, checks_for_sample())
    assert body.startswith(bm.GENERATED_MARK)
    assert len(report.accepted) == 8 and not report.rejected
    assert "POINT(139.775543 35.717556)" in body
    assert cm.statement_problems(body) == []


def test_unverified_items_are_rejected_not_written():
    # Links need no network check (both ends must exist in the DB), so leave them out here.
    unverifiable = {k: v for k, v in SAMPLE.items() if k != "movement_links"}
    body, report = bm.build(unverifiable, NOW, FakeChecks())
    assert body is None
    reasons = " ".join(report.rejected)
    assert "no page names this exhibition" in reasons
    assert "no image" in reasons
    assert "does not mention" in reasons
    assert "official site does not name this museum" in reasons


def test_exhibition_dates_are_checked():
    items = [dict(SAMPLE["exhibitions"][0], end_date="2026-10-24"),
             dict(SAMPLE["exhibitions"][0], start_date="2027-06-01", end_date="2027-07-01")]
    report = bm.Report()
    assert bm.event_statements(items, dt.date(2026, 10, 25), checks_for_sample(), report) == []
    assert len(report.rejected) == 2


def test_quotes_in_text_cannot_break_out_of_the_literal():
    item = dict(SAMPLE["news"][0], title="O'Keeffe'); drop table public.events; --",
                subject="出典に載っている固有名詞")
    body, _ = bm.build({"news": [item]}, NOW, checks_for_sample())
    assert "'O''Keeffe''); drop table public.events; --'" in body
    assert cm.statement_problems(body) == []


def test_text_keeps_full_width_marks_but_venue_names_are_unified():
    assert bm.clean("  モネ  〜睡蓮〜  ") == "モネ 〜睡蓮〜"
    assert bm.venue_name("東京国立博物館　平成館") == "東京国立博物館 平成館"
    assert bm.clean("（睡蓮）") == "（睡蓮）"


def test_gate_rejects_anything_but_content_inserts():
    bad = [
        "drop table public.events;",
        "update public.events set title = 'x';",
        "insert into public.venue_maps (image_url) values ('x');",
        "insert into auth.users (id) values (gen_random_uuid());",
        "delete from public.events;",
        "do $$ begin perform 1; end $$;",
        "insert into public.events (title) select pg_read_file('/etc/passwd');",
    ]
    for stmt in bad:
        assert cm.statement_problems(stmt), stmt
    good = "insert into public.trending_articles (title) values ('drop table; delete') on conflict (source_url) do nothing;"
    assert cm.statement_problems(good) == []


def test_gate_checks_file_names(tmp_path):
    assert cm.check_file("supabase/migrations/20261025000000_baseline.sql", tmp_path)
    assert cm.check_file("lib/main.dart", tmp_path)


def test_published_reads_items_back(tmp_path):
    from content import published

    body, _ = bm.build(SAMPLE, NOW, checks_for_sample())
    (tmp_path / "20261025000000_content_20261025.sql").write_text(body, encoding="utf-8")
    (tmp_path / "20261024000000_baseline.sql").write_text("create table x();", encoding="utf-8")
    items = published.published(tmp_path)
    assert ("exhibition", "特別展「例示の美術」 @ 東京国立博物館") in items
    assert ("daily art", "星月夜 / フィンセント・ファン・ゴッホ") in items
    assert ("artwork", "印象・日の出 / クロード・モネ") in items
    assert len(items) == 8


def test_venue_needs_geocodable_address():
    item = SAMPLE["venues"][0]
    report = bm.Report()
    no_coords = FakeChecks(pages={"https://www.tnm.jp/": "東京国立博物館"})
    assert bm.venue_statements([item], no_coords, report) == []
    assert "could not be geocoded" in report.rejected[0]


def test_art_knowledge_rows_are_checked():
    report = bm.Report()
    movements = [
        dict(SAMPLE["movements"][0], slug="Not A Slug"),
        dict(SAMPLE["movements"][0], body="短すぎる本文"),
        dict(SAMPLE["movements"][0], source_url="https://example.com/unrelated"),
    ]
    assert bm.movement_statements(movements, checks_for_sample(), report) == []
    links = [{"from": "realism", "to": "realism", "kind": "led_to", "note": "x"},
             {"from": "realism", "to": "impressionism", "kind": "friends", "note": "x"}]
    assert bm.link_statements(links, report) == []
    artworks = [dict(SAMPLE["artworks"][0], title_en="Unknown work", title="不明の作品")]
    assert bm.artwork_statements(artworks, checks_for_sample(), report) == []
    assert len(report.rejected) == 6 and not report.accepted


def test_movement_body_keeps_paragraphs():
    body, _ = bm.build({"movements": SAMPLE["movements"][:1]}, NOW, checks_for_sample())
    assert "\\n\\n" not in body  # real line breaks inside the SQL string, not escapes
    assert "描こうとした動きです。それまで" in body and "\n\nギュスターヴ" in body
