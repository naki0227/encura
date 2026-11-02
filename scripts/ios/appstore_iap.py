#!/usr/bin/env python3
"""Register the tip In-App Purchases in App Store Connect.

Creates (or completes) the three consumable tips the app sells from
「開発者を応援する」 (lib/core/services/tip_store.dart) so they reach
"Ready to Submit": product, Japanese name and description, price in yen,
availability in every territory, review note and review screenshot.
Without --apply it only reads and prints what it would change.

    python scripts/ios/appstore_iap.py [--apply]

Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (the .p8 file).
The first In-App Purchases are reviewed together with an app version;
appstore_submit.py adds them to the review submission.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys
from pathlib import Path

from appstore_submit import BUNDLE_ID, Client, refused_characters

ROOT = Path(__file__).resolve().parents[2]
SCREENSHOT = ROOT / "docs" / "appstore" / "iap_review.png"

# Same product ids, amounts and titles as tipOptions in tip_store.dart.
TIPS = [
    ("com.enludus.encura.tip.100", 100, "Tip 100", "ちょっと応援"),
    ("com.enludus.encura.tip.1000", 1000, "Tip 1000", "しっかり応援"),
    ("com.enludus.encura.tip.10000", 10000, "Tip 10000", "たっぷり応援"),
]
DESCRIPTION = "美術館に足を運ぶことと、アプリの質を上げることに使います"
REVIEW_NOTE = (
    "A tip to support the developer. It is consumable and unlocks nothing: every feature and all content "
    "stay the same, and the app only shows a thank-you message. Where to find it: Home > settings icon "
    "(top right) > 「開発者を応援する」. Tips pay for visiting museums and exhibitions and for improving "
    "the app's content."
)


def all_pages(asc: Client, path: str, **params) -> list[dict]:
    items, url = [], path
    while url:
        page = asc.get(url, **params)
        items += page["data"]
        nxt = page.get("links", {}).get("next")
        url, params = (nxt.replace("https://api.appstoreconnect.apple.com", ""), {}) if nxt else (None, {})
    return items


def check_texts() -> None:
    for _, _, _, title in TIPS:
        if len(title) > 30:
            raise SystemExit(f"display name too long: {title}")
    if len(DESCRIPTION) > 45:
        raise SystemExit(f"description is {len(DESCRIPTION)} characters (max 45)")
    for text in [DESCRIPTION, REVIEW_NOTE] + [t[3] for t in TIPS]:
        if refused_characters(text):
            raise SystemExit(f"refused characters in: {text}")
    if not SCREENSHOT.exists():
        raise SystemExit(f"missing {SCREENSHOT}")


def ensure_product(asc: Client, app_id: str, existing: dict, product_id: str, ref_name: str) -> dict | None:
    iap = existing.get(product_id)
    if iap:
        print(f"{product_id}: {iap['attributes'].get('state')}")
        if iap["attributes"].get("reviewNote") != REVIEW_NOTE:
            asc.write("PATCH", f"/v2/inAppPurchases/{iap['id']}",
                      {"data": {"type": "inAppPurchases", "id": iap["id"],
                                "attributes": {"reviewNote": REVIEW_NOTE}}},
                      f"  set the review note")
        return iap
    created = asc.write("POST", "/v2/inAppPurchases",
                        {"data": {"type": "inAppPurchases",
                                  "attributes": {"name": ref_name, "productId": product_id,
                                                 "inAppPurchaseType": "CONSUMABLE", "reviewNote": REVIEW_NOTE},
                                  "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}},
                        f"create consumable {product_id} ({ref_name})")
    return created.get("data")


def ensure_localization(asc: Client, iap_id: str, title: str) -> None:
    locs = asc.get(f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")["data"]
    ja = next((l for l in locs if l["attributes"]["locale"] in ("ja", "ja-JP")), None)
    attrs = {"name": title, "description": DESCRIPTION}
    if ja is None:
        asc.write("POST", "/v1/inAppPurchaseLocalizations",
                  {"data": {"type": "inAppPurchaseLocalizations", "attributes": {"locale": "ja", **attrs},
                            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases",
                                                                          "id": iap_id}}}}},
                  f"  add the Japanese name 「{title}」")
    elif any(ja["attributes"].get(k) != v for k, v in attrs.items()):
        asc.write("PATCH", f"/v1/inAppPurchaseLocalizations/{ja['id']}",
                  {"data": {"type": "inAppPurchaseLocalizations", "id": ja["id"], "attributes": attrs}},
                  f"  update the Japanese name 「{title}」")


def ensure_price(asc: Client, iap_id: str, yen: int) -> None:
    schedule = asc.call("GET", f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule",
                        params={"include": "manualPrices"}, ok_missing=True)
    if schedule.get("data") and schedule.get("included"):
        print("  price already set")
        return
    points = all_pages(asc, f"/v2/inAppPurchases/{iap_id}/pricePoints",
                       **{"filter[territory]": "JPN", "limit": "8000"})
    point = next((p for p in points if float(p["attributes"]["customerPrice"]) == yen), None)
    if point is None:
        raise SystemExit(f"no ¥{yen} price point in Japan")
    asc.write("POST", "/v1/inAppPurchasePriceSchedules",
              {"data": {"type": "inAppPurchasePriceSchedules",
                        "relationships": {
                            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                            "baseTerritory": {"data": {"type": "territories", "id": "JPN"}},
                            "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]}}},
               "included": [{"type": "inAppPurchasePrices", "id": "${price}",
                             "attributes": {"startDate": None},
                             "relationships": {
                                 "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}},
                                 "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints",
                                                                      "id": point["id"]}}}}]},
              f"  set the price to ¥{yen} (Japan; other countries follow Apple's equivalent)")


def ensure_availability(asc: Client, iap_id: str, territories: list[str]) -> None:
    current = asc.call("GET", f"/v2/inAppPurchases/{iap_id}/inAppPurchaseAvailability", ok_missing=True)
    if current.get("data"):
        print("  availability already set")
        return
    asc.write("POST", "/v1/inAppPurchaseAvailabilities",
              {"data": {"type": "inAppPurchaseAvailabilities",
                        "attributes": {"availableInNewTerritories": True},
                        "relationships": {
                            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                            "availableTerritories": {"data": [{"type": "territories", "id": t}
                                                              for t in territories]}}}},
              f"  make it available in all {len(territories)} territories")


def ensure_screenshot(asc: Client, iap_id: str) -> None:
    current = asc.call("GET", f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot", ok_missing=True)
    state = (current.get("data") or {}).get("attributes", {}).get("assetDeliveryState", {}).get("state")
    if state in ("UPLOAD_COMPLETE", "COMPLETE"):
        print("  review screenshot already uploaded")
        return
    if current.get("data"):
        errors = current["data"]["attributes"].get("assetDeliveryState", {}).get("errors")
        if errors:
            print(f"  Apple's error for the old screenshot: {errors}")
        asc.write("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{current['data']['id']}", None,
                  f"  remove the unfinished review screenshot ({state})")
    data = SCREENSHOT.read_bytes()
    reserved = asc.write("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots",
                         {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
                                   "attributes": {"fileName": SCREENSHOT.name, "fileSize": len(data)},
                                   "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases",
                                                                                 "id": iap_id}}}}},
                         f"  upload the review screenshot ({SCREENSHOT.name})")
    if not reserved:
        return
    shot = reserved["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        res = asc.http.request(op["method"], op["url"], data=chunk, timeout=120,
                               headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])})
        if res.status_code >= 400:
            raise SystemExit(f"screenshot upload failed: {res.status_code} {res.text[:500]}")
    asc.call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{shot['id']}",
             json={"data": {"type": "inAppPurchaseAppStoreReviewScreenshots", "id": shot["id"],
                            "attributes": {"uploaded": True,
                                           "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="make the changes (default: dry run)")
    args = parser.parse_args()
    check_texts()

    key = Path(os.environ["ASC_KEY_PATH"]).read_text()
    asc = Client(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], key, dry_run=not args.apply)
    apps = asc.get("/v1/apps", **{"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        raise SystemExit(f"no app with bundle id {BUNDLE_ID}")
    app_id = apps[0]["id"]
    existing = {i["attributes"]["productId"]: i
                for i in all_pages(asc, f"/v1/apps/{app_id}/inAppPurchasesV2", limit="200")}
    territories = [t["id"] for t in all_pages(asc, "/v1/territories", limit="200")]

    for product_id, yen, ref_name, title in TIPS:
        iap = ensure_product(asc, app_id, existing, product_id, ref_name)
        if not iap:
            print(f"  [dry run] would then add 「{title}」, ¥{yen}, availability and the review screenshot")
            continue
        ensure_localization(asc, iap["id"], title)
        ensure_price(asc, iap["id"], yen)
        ensure_availability(asc, iap["id"], territories)
        ensure_screenshot(asc, iap["id"])

    if args.apply:
        print("\nstates now:")
        for i in all_pages(asc, f"/v1/apps/{app_id}/inAppPurchasesV2", limit="200"):
            print(f"  {i['attributes']['productId']}: {i['attributes'].get('state')}")
    print("done" if args.apply else "dry run finished: nothing was changed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
