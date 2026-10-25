from common import gemini


def test_models_from_env(monkeypatch):
    monkeypatch.delenv("GEMINI_MODEL", raising=False)
    assert gemini.models_from_env() == gemini.DEFAULT_MODELS
    monkeypatch.setenv("GEMINI_MODEL", "a, b ,")
    assert gemini.models_from_env() == ["a", "b"]


def test_error_message():
    assert gemini.error_message('{"error": {"message": "API key not valid"}}') == "API key not valid"
    assert gemini.error_message("plain text") == "plain text"
