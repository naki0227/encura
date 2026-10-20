import pytest

from common import gemini
from conftest import FakeResponse, FakeSession


def answer(text, sources=()):
    return {"candidates": [{
        "content": {"parts": [{"text": text}]},
        "groundingMetadata": {"groundingChunks": [{"web": {"uri": u, "title": "t"}} for u in sources]},
    }]}


@pytest.fixture(autouse=True)
def key(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "test-key")
    monkeypatch.delenv("GEMINI_MODEL", raising=False)


def test_models_from_env(monkeypatch):
    assert gemini.models_from_env() == gemini.DEFAULT_MODELS
    monkeypatch.setenv("GEMINI_MODEL", "a, b ,")
    assert gemini.models_from_env() == ["a", "b"]


def test_falls_through_to_next_model_when_one_is_retired():
    http = FakeSession([
        ("/old:generateContent", FakeResponse(404, {"error": {"message": "models/old is not found"}})),
        ("/new:generateContent", FakeResponse(200, answer("[]", ["https://src.example/"]))),
    ])
    result = gemini.generate("p", search=True, models=["old", "new"], session=http)
    assert result.model == "new"
    assert [s.uri for s in result.sources] == ["https://src.example/"]
    assert '"google_search"' in http.calls[-1][1]["data"]


def test_bad_key_fails_fast_without_trying_other_models():
    http = FakeSession([("/a:generateContent", FakeResponse(400, {"error": {"message": "API key not valid"}}))])
    with pytest.raises(gemini.GeminiError, match="API key not valid"):
        gemini.generate("p", models=["a", "b"], session=http)
    assert len(http.calls) == 1


def test_missing_key(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY")
    with pytest.raises(gemini.GeminiError, match="GEMINI_API_KEY"):
        gemini.generate("p", models=["a"], session=FakeSession([]))


@pytest.mark.parametrize("text", [
    '```json\n[{"a": 1}]\n```',
    'Here you go:\n[{"a": 1}]\nThanks',
    '[{"a": 1}]',
])
def test_extract_json(text):
    assert gemini.extract_json(text) == [{"a": 1}]


def test_extract_json_rejects_prose():
    with pytest.raises(gemini.GeminiError):
        gemini.extract_json("I could not find anything.")
