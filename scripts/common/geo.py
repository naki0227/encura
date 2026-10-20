"""Address -> coordinates with the GSI (国土地理院) address search API."""
from __future__ import annotations

import requests

GSI_URL = "https://msearch.gsi.go.jp/address-search/AddressSearch"

# Rough bounding box of Japan, to reject obviously wrong hits.
_LAT = (20.0, 46.0)
_LON = (122.0, 154.0)


def in_japan(lat: float, lon: float) -> bool:
    return _LAT[0] <= lat <= _LAT[1] and _LON[0] <= lon <= _LON[1]


def geocode(address: str, session: requests.Session | None = None) -> tuple[float, float] | None:
    """Return (lat, lon) for a Japanese address, or None."""
    if not address or not address.strip():
        return None
    http = session or requests.Session()
    try:
        res = http.get(GSI_URL, params={"q": address.strip()}, timeout=20)
        res.raise_for_status()
        features = res.json()
    except (requests.RequestException, ValueError):
        return None
    for feature in features or []:
        try:
            lon, lat = feature["geometry"]["coordinates"][:2]
        except (KeyError, TypeError, ValueError):
            continue
        if in_japan(lat, lon):
            return float(lat), float(lon)
    return None


def to_wkt(lat: float, lon: float) -> str:
    return f"SRID=4326;POINT({lon} {lat})"
