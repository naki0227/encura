from common import geo, web
from conftest import FakeResponse, FakeSession


def test_mentions_ignores_brackets_width_and_spacing():
    page = "<html><body><h1>特別展『ＭＯＮＥＴ　睡蓮のとき』</h1></body></html>"
    assert web.mentions(web.html_to_text(page), "モネ 睡蓮のとき") is False
    assert web.mentions(web.html_to_text(page), "MONET 睡蓮のとき")


def test_mentions_accepts_main_title_without_subtitle():
    page = "開催中：大浮世絵展　会期は…"
    assert web.mentions(page, "大浮世絵展 ―歌麿、写楽、北斎、広重―")
    assert not web.mentions(page, "大琳派展 ―継承と変奏―")


def test_find_page_mentioning_skips_unreachable_and_unrelated_pages():
    http = FakeSession([
        ("official", FakeResponse(403)),
        ("news", FakeResponse(200, "<p>別の展覧会</p>")),
        ("museum", FakeResponse(200, "<p>大浮世絵展</p>", url="https://museum.example/ex")),
    ])
    found = web.find_page_mentioning(
        "大浮世絵展", ["https://official.example/", "https://news.example/", "https://museum.example/"], http)
    assert found == "https://museum.example/ex"


def test_fetch_rejects_non_http_and_non_html():
    assert web.fetch("javascript:alert(1)") is None
    http = FakeSession([("pdf", FakeResponse(200, "%PDF", headers={"content-type": "application/pdf"}))])
    assert web.fetch("https://x.example/a.pdf", http) is None


def test_geocode_uses_first_hit_inside_japan():
    http = FakeSession([("AddressSearch", FakeResponse(200, [
        {"geometry": {"coordinates": [0.0, 0.0]}},
        {"geometry": {"coordinates": [139.775543, 35.717556]}},
    ]))])
    assert geo.geocode("東京都台東区上野公園13-9", http) == (35.717556, 139.775543)


def test_geocode_handles_empty_and_errors():
    assert geo.geocode("") is None
    http = FakeSession([("AddressSearch", FakeResponse(500, "oops"))])
    assert geo.geocode("どこか", http) is None


def test_to_wkt_is_lon_lat():
    assert geo.to_wkt(35.7, 139.7) == "SRID=4326;POINT(139.7 35.7)"
