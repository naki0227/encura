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
        pages={"https://www.tnm.jp/": "特別展「例示の美術」", "https://example.com/article": "出典に載っている固有名詞"},
        images={"The Starry Night": "https://upload.wikimedia.org/starry.jpg"},
        coords=(35.717556, 139.775543),
    )


def test_sample_produces_a_migration_that_passes_the_gate(tmp_path):
    body, report = bm.build(SAMPLE, NOW, checks_for_sample())
    assert body.startswith(bm.GENERATED_MARK)
    assert len(report.accepted) == 3 and not report.rejected
    assert "POINT(139.775543 35.717556)" in body
    assert cm.statement_problems(body) == []


def test_unverified_items_are_rejected_not_written():
    body, report = bm.build(SAMPLE, NOW, FakeChecks())
    assert body is None
    reasons = " ".join(report.rejected)
    assert "no page names this exhibition" in reasons
    assert "no image" in reasons
    assert "does not mention" in reasons


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
    assert len(items) == 3
