import io
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


class FakeResponse:
    def __init__(self, status=200, body=None, headers=None, url="https://example.jp/"):
        self.status_code = status
        if isinstance(body, (dict, list)):
            body = json.dumps(body)
        self.text = body or ""
        self.headers = {"content-type": "text/html; charset=utf-8", **(headers or {})}
        self.url = url
        self.encoding = "utf-8"
        self.apparent_encoding = "utf-8"
        self.raw = io.BytesIO(self.text.encode())
        self.raw.read = (lambda f: lambda n=-1, decode_content=True: f(n))(self.raw.read)

    def json(self):
        return json.loads(self.text)

    def raise_for_status(self):
        if self.status_code >= 400:
            import requests
            raise requests.HTTPError(str(self.status_code))


class FakeSession:
    """Replies are matched in order by a substring of the URL."""

    def __init__(self, routes):
        self.routes = list(routes)
        self.calls = []

    def _reply(self, url, **kwargs):
        self.calls.append((url, kwargs))
        target = url + "?" + "&".join(f"{k}={v}" for k, v in (kwargs.get("params") or {}).items())
        for i, (needle, response) in enumerate(self.routes):
            if needle in target:
                self.routes.pop(i)
                return response
        raise AssertionError(f"unexpected request: {url}")

    def get(self, url, **kwargs):
        return self._reply(url, **kwargs)

    def post(self, url, **kwargs):
        return self._reply(url, **kwargs)
