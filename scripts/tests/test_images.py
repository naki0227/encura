from common import images
from conftest import FakeResponse, FakeSession


def entity(image=None, creator=None, label=""):
    claims = {}
    if image:
        claims["P18"] = [{"mainsnak": {"datavalue": {"value": image}}}]
    if creator:
        claims["P170"] = [{"mainsnak": {"datavalue": {"value": {"id": creator}}}}]
    return {"claims": claims, "labels": {"en": {"value": label}}}


def test_accepts_image_only_when_the_creator_matches():
    http = FakeSession([
        ("wbsearchentities", FakeResponse(200, {"search": [{"id": "Q1"}, {"id": "Q2"}]})),
        ("wbgetentities", FakeResponse(200, {"entities": {
            "Q1": entity("Wrong.jpg", "Q10"),            # same title, other artist
            "Q2": entity("Starry.jpg", "Q11"),
        }})),
        ("wbgetentities", FakeResponse(200, {"entities": {
            "Q10": entity(label="Someone Else"),
            "Q11": entity(label="Vincent van Gogh"),
        }})),
        ("commons.wikimedia.org", FakeResponse(200, {"query": {"pages": {"1": {"imageinfo": [
            {"mime": "image/jpeg", "thumburl": "https://upload.wikimedia.org/thumb/Starry.jpg"}]}}}})),
    ])
    url = images.find_artwork_image(["The Starry Night"], ["Vincent van Gogh"], http)
    assert url == "https://upload.wikimedia.org/thumb/Starry.jpg"


def test_returns_none_instead_of_a_loose_match():
    http = FakeSession([
        ("wbsearchentities", FakeResponse(200, {"search": [{"id": "Q1"}]})),
        ("wbgetentities", FakeResponse(200, {"entities": {"Q1": entity("Wrong.jpg", "Q10")}})),
        ("wbgetentities", FakeResponse(200, {"entities": {"Q10": entity(label="Someone Else")}})),
        ("wbsearchentities", FakeResponse(200, {"search": []})),
    ])
    assert images.find_artwork_image(["Untitled"], ["Claude Monet"], http) is None
