#!/usr/bin/env python3
"""Prepare an App Store version and (optionally) submit it for review.

Uses the App Store Connect API with the same team key as the TestFlight
workflow. Without --submit it only reads and prints what it would change.

    python scripts/ios/appstore_submit.py --version 1.0.5 --build 17 [--submit]

Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (the .p8 file).

What it sets (from docs/RELEASE.md, "リリースノート案（<version>）"):
  * the version <version>, created if missing, with build <build> attached
  * "What's New", support URL and marketing URL for every localization
  * the privacy policy URL for every app info localization
  * the review contact e-mail
Things the API cannot change (App Privacy answers, screenshots) stay as they
are in App Store Connect.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import time
from pathlib import Path

import jwt
import requests

API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "com.enludus.encura"
SUPPORT_URL = "https://enludus.com"
MARKETING_URL = "https://enludus.com"
PRIVACY_URL = "https://enludus.com/products/encura-privacy"
CONTACT_EMAIL = "contact@enludus.com"
RELEASE_DOC = Path(__file__).resolve().parents[2] / "docs" / "RELEASE.md"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
            "INVALID_BINARY", "DEVELOPER_REMOVED_FROM_SALE"}


class Client:
    def __init__(self, key_id: str, issuer: str, key: str, dry_run: bool):
        self.key_id, self.issuer, self.key, self.dry_run = key_id, issuer, key, dry_run
        self.http = requests.Session()

    def _token(self) -> str:
        now = int(time.time())
        return jwt.encode({"iss": self.issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                          self.key, algorithm="ES256", headers={"kid": self.key_id, "typ": "JWT"})

    def call(self, method: str, path: str, ok_conflict: bool = False, **kw) -> dict:
        res = self.http.request(method, API + path, headers={"Authorization": f"Bearer {self._token()}"},
                                timeout=60, **kw)
        if res.status_code == 409 and ok_conflict and "already" in res.text.lower():
            print("  (already done)")
            return {}
        if res.status_code >= 400:
            # Apple lists what is missing in associatedErrors; print it all.
            raise SystemExit(f"{method} {path} -> {res.status_code}: {res.text[:6000]}")
        return res.json() if res.content else {}

    def get(self, path: str, **params) -> dict:
        return self.call("GET", path, params=params)

    def write(self, method: str, path: str, body: dict, what: str, ok_conflict: bool = False) -> dict:
        print(("[dry run] would " if self.dry_run else "") + what)
        if self.dry_run:
            return {}
        return self.call(method, path, ok_conflict=ok_conflict, json=body)


def release_notes(version: str) -> str:
    text = RELEASE_DOC.read_text(encoding="utf-8")
    match = re.search(rf"## リリースノート案（{re.escape(version)}）\s*```\n(.*?)\n```", text, re.S)
    if not match:
        raise SystemExit(f"no release notes for {version} in {RELEASE_DOC}")
    notes = match.group(1).strip()
    # App Store Connect refuses symbols such as ♡ and emoji in "What's New".
    bad = sorted({c for c in notes if ord(c) > 0xFFFF or 0x2600 <= ord(c) <= 0x27BF})
    if bad:
        raise SystemExit(f"release notes contain characters App Store Connect refuses: {' '.join(bad)}")
    if len(notes) > 4000:
        raise SystemExit("release notes are longer than 4000 characters")
    return notes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True, help="CFBundleVersion of the TestFlight build")
    parser.add_argument("--submit", action="store_true", help="make the changes and submit for review")
    args = parser.parse_args()

    key = Path(os.environ["ASC_KEY_PATH"]).read_text()
    asc = Client(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], key, dry_run=not args.submit)
    notes = release_notes(args.version)

    apps = asc.get("/v1/apps", **{"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        raise SystemExit(f"no app with bundle id {BUNDLE_ID}")
    app_id = apps[0]["id"]
    print(f"app: {apps[0]['attributes']['name']} ({BUNDLE_ID})")

    builds = asc.get("/v1/builds", **{"filter[app]": app_id, "filter[version]": args.build,
                                      "filter[preReleaseVersion.version]": args.version})["data"]
    if not builds:
        raise SystemExit(f"build {args.version} ({args.build}) is not in App Store Connect yet")
    build = builds[0]
    state = build["attributes"].get("processingState")
    print(f"build: {args.version} ({args.build}), processing {state}")
    if state != "VALID":
        raise SystemExit("the build has not finished processing; try again later")

    versions = asc.get(f"/v1/apps/{app_id}/appStoreVersions",
                       **{"filter[platform]": "IOS", "limit": "20"})["data"]
    live = [v for v in versions if v["attributes"]["appStoreState"] == "READY_FOR_SALE"]
    if live:
        print(f"on sale now: {live[0]['attributes']['versionString']}")
    version = next((v for v in versions if v["attributes"]["versionString"] == args.version), None)
    if version and version["attributes"]["appStoreState"] not in EDITABLE:
        raise SystemExit(f"version {args.version} is {version['attributes']['appStoreState']}; nothing to do")
    other = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE
             and v["attributes"]["versionString"] != args.version]
    if other and not version:
        # Only one version can be in preparation; rename it rather than add one.
        version = other[0]
        asc.write("PATCH", f"/v1/appStoreVersions/{version['id']}",
                  {"data": {"type": "appStoreVersions", "id": version["id"],
                            "attributes": {"versionString": args.version}}},
                  f"rename version {version['attributes']['versionString']} to {args.version}")
    if not version:
        created = asc.write("POST", "/v1/appStoreVersions",
                            {"data": {"type": "appStoreVersions",
                                      "attributes": {"platform": "IOS", "versionString": args.version},
                                      "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}},
                            f"create version {args.version}")
        version = created.get("data")
    else:
        print(f"version: {args.version} ({version['attributes']['appStoreState']})")

    if version:
        vid = version["id"]
        asc.write("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build",
                  {"data": {"type": "builds", "id": build["id"]}}, f"select build {args.build}")
        for loc in asc.get(f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]:
            asc.write("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}",
                      {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"],
                                "attributes": {"whatsNew": notes, "supportUrl": SUPPORT_URL,
                                               "marketingUrl": MARKETING_URL}}},
                      f"set What's New, support and marketing URLs ({loc['attributes']['locale']}; "
                      f"support now {loc['attributes'].get('supportUrl')})")
        detail = asc.get(f"/v1/appStoreVersions/{vid}/appStoreReviewDetail").get("data")
        if detail and detail["attributes"].get("contactEmail") != CONTACT_EMAIL:
            asc.write("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}",
                      {"data": {"type": "appStoreReviewDetails", "id": detail["id"],
                                "attributes": {"contactEmail": CONTACT_EMAIL}}},
                      "set the review contact e-mail")
    else:
        print("[dry run] the new version's texts and build would be set after it is created")

    for info in asc.get(f"/v1/apps/{app_id}/appInfos")["data"]:
        if info["attributes"].get("appStoreState") not in EDITABLE and info["attributes"].get("state") not in (
                "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"):
            continue
        for loc in asc.get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]:
            if loc["attributes"].get("privacyPolicyUrl") != PRIVACY_URL:
                asc.write("PATCH", f"/v1/appInfoLocalizations/{loc['id']}",
                          {"data": {"type": "appInfoLocalizations", "id": loc["id"],
                                    "attributes": {"privacyPolicyUrl": PRIVACY_URL}}},
                          f"set the privacy policy URL ({loc['attributes']['locale']}; "
                          f"now {loc['attributes'].get('privacyPolicyUrl')})")

    print("\nWhat's New:\n" + notes + "\n")
    if not version:
        return 0
    open_subs = asc.get("/v1/reviewSubmissions", **{"filter[app]": app_id, "filter[platform]": "IOS",
                                                    "filter[state]": "READY_FOR_REVIEW"})["data"]
    if open_subs:
        sub = open_subs[0]
    else:
        sub = asc.write("POST", "/v1/reviewSubmissions",
                        {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                                  "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}},
                        "open a review submission").get("data")
    if sub:
        asc.write("POST", "/v1/reviewSubmissionItems",
                  {"data": {"type": "reviewSubmissionItems", "relationships": {
                      "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                      "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}},
                  f"add version {args.version} to the submission", ok_conflict=True)
        asc.write("PATCH", f"/v1/reviewSubmissions/{sub['id']}",
                  {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}},
                  "submit for review")
    else:
        print("[dry run] would open a review submission, add the version and submit it")
    print("submitted for review" if args.submit else "dry run finished: nothing was changed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
