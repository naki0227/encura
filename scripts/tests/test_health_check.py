import health_check as hc
from conftest import FakeResponse, FakeSession


def test_models_ok(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "k")
    monkeypatch.setenv("GEMINI_MODEL", "gemini-3.8-flash")
    http = FakeSession([("models", FakeResponse(200, {"models": [{"name": "models/gemini-3.8-flash"}]}))])
    assert hc.check_gemini_models(http).status == hc.OK


def test_models_warn_on_fallback_and_fail_when_all_gone(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "k")
    monkeypatch.setenv("GEMINI_MODEL", "gemini-old-flash,gemini-3.8-flash")
    served = {"models": [{"name": "models/gemini-3.8-flash"}, {"name": "models/gemini-9-flash"}]}
    assert hc.check_gemini_models(FakeSession([("models", FakeResponse(200, served))])).status == hc.WARN
    monkeypatch.setenv("GEMINI_MODEL", "gemini-old-flash")
    result = hc.check_gemini_models(FakeSession([("models", FakeResponse(200, served))]))
    assert result.status == hc.FAIL
    assert "gemini-9-flash" in result.detail


def test_revoked_key_fails(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "revoked")
    http = FakeSession([("models", FakeResponse(400, {"error": {"message": "API key not valid"}}))])
    result = hc.check_gemini_models(http)
    assert result.status == hc.FAIL and "400" in result.detail


def test_optimizer_html_placeholder_is_flagged(monkeypatch):
    monkeypatch.setenv("IMAGE_OPTIMIZER_URL", "https://opt.example/process")
    http = FakeSession([("opt.example", FakeResponse(200, "<title>Placeholder</title>"))])
    assert hc.check_image_optimizer(http).status == hc.WARN


def test_paused_supabase_fails(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://p.supabase.co")
    monkeypatch.setenv("SUPABASE_ANON_KEY", "anon")
    http = FakeSession([("daily_columns", FakeResponse(540, "project paused"))])
    assert hc.check_supabase_content(http).status == hc.FAIL


def test_missing_settings_are_skipped_and_crashes_are_failures(monkeypatch):
    for name in ("GEMINI_API_KEY", "SUPABASE_URL", "SUPABASE_ANON_KEY", "IMAGE_OPTIMIZER_URL"):
        monkeypatch.delenv(name, raising=False)
    results = hc.run(http=FakeSession([]))
    assert {r.status for r in results} == {hc.SKIP}

    def boom(_):
        raise RuntimeError("x")
    assert hc.run([boom], FakeSession([]))[0].status == hc.FAIL
