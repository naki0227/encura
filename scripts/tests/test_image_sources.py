from common import museums
from common.image_info import commons_file_name, is_allowed, needs_credit


def test_licenses_that_may_be_shown():
    for ok in ("Public domain", "PD-old-100", "CC0", "CC BY 4.0", "CC BY-SA 3.0", "CC-BY-SA-4.0"):
        assert is_allowed(ok), ok
    for no in ("", "GFDL", "All rights reserved", "CC BY-NC 4.0", "Fair use"):
        assert not is_allowed(no), no
    assert needs_credit("CC BY-SA 4.0") and not needs_credit("Public domain")


def test_commons_file_name_from_urls():
    thumb = ("https://thumb.wikimedia.org/wikipedia/commons/thumb/e/ec/"
             "Mona_Lisa%2C_by_Leonardo_da_Vinci.jpg/960px-Mona_Lisa%2C_by_Leonardo_da_Vinci.jpg")
    assert commons_file_name(thumb) == "Mona_Lisa,_by_Leonardo_da_Vinci.jpg"
    original = "https://upload.wikimedia.org/wikipedia/commons/c/c7/%E5%85%AD%E6%9F%BF%E5%9B%B3.jpg"
    assert commons_file_name(original) == "六柿図.jpg"
    assert commons_file_name("https://images.metmuseum.org/CRDImages/ep/web-large/DT1.jpg") is None


def test_museum_hits_must_match_artist_and_title():
    assert museums.artist_matches("Claude Monet", "Claude Monet (French, 1840–1926)")
    assert museums.artist_matches("Jean-Léon Gérôme", "Jean-Leon Gerome")
    assert not museums.artist_matches("Claude Monet", "Édouard Manet")
    assert museums.title_matches("Bridge over a Pond of Water Lilies", "Bridge over a Pond of Water Lilies")
    assert museums.title_matches("The Card Players", "The Card Players")
    assert not museums.title_matches("The Card Players", "Still Life with Apples")
