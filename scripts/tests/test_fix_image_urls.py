import fix_image_urls as fix

BASE = "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Starry.jpg"


def test_rewrites_width_when_the_allowed_size_loads():
    row = {"title": "星月夜", "artist": "ゴッホ", "image_url": f"{BASE}/800px-Starry.jpg"}
    assert fix.repair(row, "daily_columns", check=lambda u: "ok") == f"{BASE}/960px-Starry.jpg"


def test_leaves_good_urls_and_unknown_status_alone():
    row = {"title": "t", "image_url": f"{BASE}/960px-Starry.jpg"}
    assert fix.repair(row, "trending_articles", check=lambda u: "ok") is None
    assert fix.repair({**row, "image_url": f"{BASE}/800px-Starry.jpg"}, "trending_articles",
                      check=lambda u: "unknown") is None


def test_broken_daily_art_is_looked_up_again_else_cleared():
    row = {"title": "星月夜", "artist": "ゴッホ", "image_url": "https://dead.example/a.jpg"}
    assert fix.repair(row, "daily_columns", check=lambda u: "broken",
                      lookup=lambda t, a: "https://new.example/a.jpg") == "https://new.example/a.jpg"
    assert fix.repair(row, "daily_columns", check=lambda u: "broken", lookup=lambda t, a: None) == ""
    assert fix.repair({"title": "t", "image_url": "https://dead.example/b.jpg"}, "trending_articles",
                      check=lambda u: "broken") == ""
