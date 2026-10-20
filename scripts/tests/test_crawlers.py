import datetime as dt

import daily_crawler
import seasonal_exhibitions
import seed_daily_art
import trend_art_crawler

TODAY = dt.date(2026, 10, 20)


def event(**kw):
    base = {"title": "大浮世絵展", "venue": "東京国立博物館", "venue_address": "東京都台東区上野公園13-9",
            "start_date": "2026-10-01", "end_date": "2026-12-01", "official_url": "https://x.example/"}
    return {**base, **kw}


def test_parse_candidates_keeps_only_current_well_formed_events():
    items = [
        event(),
        event(title="終わった展", end_date="2026-10-19"),
        event(title="逆転", start_date="2026-12-02"),
        event(title="ずっと先", start_date="2027-03-01", end_date="2027-04-01"),
        event(title="日付なし", start_date="未定"),
        event(title=""),
        "not a dict",
    ]
    assert [c.title for c in daily_crawler.parse_candidates(items, TODAY)] == ["大浮世絵展"]
    assert daily_crawler.parse_candidates({"oops": 1}, TODAY) == []


def test_match_venue_ignores_spacing_and_width():
    venues = [{"id": 1, "name": "東京国立博物館　平成館"}]
    assert daily_crawler.match_venue("東京国立博物館 平成館", venues)["id"] == 1
    assert daily_crawler.match_venue("国立西洋美術館", venues) is None


def test_missing_dates_fills_gaps_only():
    existing = {"2026-10-20", "2026-10-22"}
    dates = seed_daily_art.missing_dates(existing, TODAY, days=3)
    assert dates == [dt.date(2026, 10, 21), dt.date(2026, 10, 23)]


def test_daily_art_skips_known_and_incomplete_items():
    known = {"星月夜"}
    items = [
        {"title": "星月夜", "artist": "ゴッホ", "content": "x"},
        {"title": "睡蓮", "artist": "モネ", "content": "x"},
        {"title": "睡蓮", "artist": "モネ", "content": "x"},
        {"title": "無題", "artist": "", "content": "x"},
    ]
    assert [i["title"] for i in seed_daily_art.valid_items(items, known)] == ["睡蓮"]


def test_trend_topics_dedupe_by_title_and_source():
    items = [
        {"title": "A", "summary": "s", "content": "c", "source_url": "https://old.example/", "keyword": "展覧会"},
        {"title": "B", "summary": "s", "content": "c", "source_url": "https://new.example/", "keyword": "ゴシップ"},
        {"title": "既出", "summary": "s", "content": "c"},
    ]
    topics = trend_art_crawler.valid_topics(items, {"既出"}, {"https://old.example/"})
    assert [t["title"] for t in topics] == ["B"]
    assert topics[0]["keyword"] in trend_art_crawler.KEYWORDS


def test_trend_anchor_prefers_specific_subject():
    assert trend_art_crawler.anchor_phrase({"title": "見出し", "subject": "大浮世絵展"}) == "大浮世絵展"
    assert trend_art_crawler.anchor_phrase({"title": "見出し", "subject": "展"}) == "見出し"


def test_seasonal_accepts_only_this_years_announcement():
    ok = {"announced": True, "start_date": "2026-10-25", "end_date": "2026-11-10",
          "summary": "s", "content": "c"}
    assert seasonal_exhibitions.check_announcement(ok, 2026) == ok
    assert seasonal_exhibitions.check_announcement({"announced": False}, 2026) is None
    assert seasonal_exhibitions.check_announcement({**ok, "start_date": "2025-10-25", "end_date": "2025-11-10"}, 2026) is None
    assert seasonal_exhibitions.check_announcement({**ok, "content": ""}, 2026) is None


def test_seasonal_relevant_wraps_december_to_january():
    exhibitions = [{"name": "a", "month": 1}, {"name": "b", "month": 6}]
    assert [e["name"] for e in seasonal_exhibitions.relevant(exhibitions, 12)] == ["a"]
