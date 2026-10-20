"""Supabase client for the crawlers (service role, server side only)."""
from __future__ import annotations

import os
import sys


def require_env(*names: str) -> dict[str, str]:
    values = {n: os.environ.get(n, "").strip() for n in names}
    missing = [n for n, v in values.items() if not v]
    if missing:
        print(f"Error: missing environment variables: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)
    return values


def client():
    from supabase import create_client

    env = require_env("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
    return create_client(env["SUPABASE_URL"], env["SUPABASE_SERVICE_ROLE_KEY"])
