"""Small helpers for writing SQL literals safely."""
from __future__ import annotations

import datetime as dt


def text(value: str | None) -> str:
    if value is None:
        return "null"
    value = str(value)
    if "\x00" in value:
        raise ValueError("NUL byte in value")
    return "'" + value.replace("'", "''") + "'"


def date(value: dt.date) -> str:
    return f"date '{value.isoformat()}'"


def point(coords: tuple[float, float] | None) -> str:
    if not coords:
        return "null"
    lat, lon = (float(c) for c in coords)
    return f"extensions.st_geogfromtext('SRID=4326;POINT({lon} {lat})')"


def jsonb_summary(summary: str) -> str:
    # jsonb_build_object keeps escaping inside SQL instead of hand-built JSON.
    return f"jsonb_build_object('summary', {text(summary)})"
