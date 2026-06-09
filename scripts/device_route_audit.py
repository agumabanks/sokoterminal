#!/usr/bin/env python3
"""Launches the seller terminal into internal routes and captures UI dumps."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path


PACKAGE = "com.soko24.soko_seller_terminal"
ACTIVITY = f"{PACKAGE}/{PACKAGE}.MainActivity"

ROUTES = [
    ("Checkout", "/home/checkout"),
    ("Transactions", "/home/transactions"),
    ("Alerts", "/home/notifications"),
    ("More", "/home/more"),
    ("Dashboard", "/home/more/dashboard"),
    ("Products", "/home/more/items"),
    ("Suppliers", "/home/more/suppliers"),
    ("Purchase Orders", "/home/more/purchase-orders"),
    ("Receive Stock", "/home/more/receive-stock"),
    ("Stock Count", "/home/more/stocktake"),
    ("Low Stock", "/home/more/low-stock"),
    ("Services", "/home/more/services"),
    ("Orders", "/home/more/orders"),
    ("Auctions", "/home/more/auctions"),
    ("Messages", "/home/more/chat"),
    ("Insights & Analytics", "/home/more/analytics"),
    ("Coupons", "/home/more/coupons"),
    ("Quotations", "/home/more/quotations"),
    ("Digital Catalog", "/home/more/catalog"),
    ("Wholesale & Digital", "/home/more/wholesale"),
    ("Ads & Creatives", "/home/more/ads"),
    ("Bulk SMS", "/home/more/bulk-sms"),
    ("Reports", "/home/more/reports"),
    ("Expenses", "/home/more/expenses"),
    ("Refunds", "/home/more/refunds"),
    ("App Settings", "/home/more/settings"),
    ("Delivery Options", "/home/more/delivery-settings"),
    ("Print Queue", "/home/more/print-queue"),
    ("Print Diagnostics", "/home/more/print-diagnostics"),
    ("Sync Health", "/home/more/sync-health"),
    ("Export", "/home/more/export"),
    ("Profile", "/home/more/profile"),
    ("Seller Profile", "/home/more/seller-profile"),
    ("Shop Settings", "/home/more/shop-info"),
    ("Shop SEO", "/home/more/shop-seo"),
    ("Payment Settings", "/home/more/payment-settings"),
    ("Sanaa Wallet", "/home/more/wallet"),
    ("Verification", "/home/more/verification"),
    ("Staff & Roles", "/home/more/staff"),
    ("Shifts & Cash", "/home/more/shifts"),
    ("Customers", "/home/more/contacts"),
    ("Receipt Templates", "/home/more/receipt-templates"),
    ("Backup & Restore", "/home/more/backup"),
    ("Void Reason Codes", "/home/more/void-reason-codes"),
    ("Business Setup", "/home/more/business-setup"),
]


def adb(*args: str, timeout: int = 90) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["adb", *args],
        text=True,
        capture_output=True,
        check=True,
        timeout=timeout,
    )


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def unique_strings(root: ET.Element, limit: int = 20) -> list[str]:
    seen: list[str] = []
    for node in root.iter("node"):
        for attr in ("content-desc", "text"):
            raw = (node.attrib.get(attr) or "").strip()
            if not raw:
                continue
            raw = raw.replace("\n", " | ")
            if raw not in seen:
                seen.append(raw)
        if len(seen) >= limit:
            break
    return seen[:limit]


def dump_ui(path: Path) -> ET.Element:
    proc = subprocess.run(
        ["adb", "exec-out", "uiautomator", "dump", "/dev/tty"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=90,
        check=True,
    )
    text = proc.stdout.replace(b"\r", b"").decode("utf-8", errors="ignore")
    if "null root node returned" in text:
        raise RuntimeError("uiautomator returned a null root node")
    end = text.rfind("</hierarchy>")
    if end == -1:
        raise RuntimeError("uiautomator dump did not contain a hierarchy root")
    clean = text[: end + len("</hierarchy>")]
    path.write_text(clean, encoding="utf-8")
    return ET.fromstring(clean)


def find_node(root: ET.Element, query: str) -> ET.Element | None:
    query_lower = query.lower()
    for node in root.iter("node"):
        desc = (node.attrib.get("content-desc") or "").lower()
        text = (node.attrib.get("text") or "").lower()
        if query_lower in desc or query_lower in text:
            return node
    return None


class RouteAudit:
    def __init__(self, outdir: Path, screenshots: bool) -> None:
        self.outdir = outdir
        self.screenshots = screenshots
        self.results: dict[str, object] = {
            "package": PACKAGE,
            "activity": ACTIVITY,
            "generated_at_epoch": int(time.time()),
            "screenshots": screenshots,
            "routes": [],
        }
        self.outdir.mkdir(parents=True, exist_ok=True)

    def log(self, message: str) -> None:
        print(message, flush=True)

    def screenshot(self, path: Path) -> None:
        proc = subprocess.run(
            ["adb", "exec-out", "screencap", "-p"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=90,
            check=True,
        )
        path.write_bytes(proc.stdout)

    def launch_route(self, route: str) -> None:
        adb("shell", "am", "force-stop", PACKAGE)
        adb("shell", "am", "start", "-n", ACTIVITY, "--es", "route", route)

    def wait_for_ready(self) -> None:
        last_error: str | None = None
        for idx in range(20):
            time.sleep(2)
            try:
                root = dump_ui(self.outdir / f"route-ready-{idx}.xml")
                if find_node(root, "Checking staff session") is not None:
                    continue
                if root is not None:
                    return
            except Exception as exc:  # pragma: no cover - adb/device dependent
                last_error = str(exc)
        raise RuntimeError(last_error or "app did not reach a ready route state")

    def capture_route(self, label: str, route: str) -> dict[str, object]:
        self.log(f"ROUTE {label} {route}")
        self.launch_route(route)
        self.wait_for_ready()
        stem = slugify(label)
        xml_path = self.outdir / f"{stem}.xml"
        png_path = self.outdir / f"{stem}.png"
        last_error: str | None = None
        for _ in range(12):
            time.sleep(2)
            try:
                root = dump_ui(xml_path)
                record = {
                    "label": label,
                    "route": route,
                    "status": "opened",
                    "xml": str(xml_path),
                    "strings": unique_strings(root),
                }
                if self.screenshots:
                    self.screenshot(png_path)
                    record["png"] = str(png_path)
                return record
            except Exception as exc:  # pragma: no cover - adb/device dependent
                last_error = str(exc)
        return {
            "label": label,
            "route": route,
            "status": "failed",
            "error": last_error or "unknown route launch failure",
        }

    def run(self) -> None:
        for label, route in ROUTES:
            self.results["routes"].append(self.capture_route(label, route))  # type: ignore[index]
        (self.outdir / "device-route-audit.json").write_text(
            json.dumps(self.results, indent=2),
            encoding="utf-8",
        )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--outdir",
        default="/var/www/soko/artifacts/device-route-audit",
        help="Where to store xml/png/json artifacts.",
    )
    parser.add_argument(
        "--screenshots",
        action="store_true",
        help="Capture screenshots in addition to XML.",
    )
    args = parser.parse_args(argv)

    audit = RouteAudit(Path(args.outdir), screenshots=args.screenshots)
    try:
        audit.run()
    except Exception as exc:  # pragma: no cover - runtime harness
        audit.results["fatal_error"] = str(exc)
        (audit.outdir / "device-route-audit.json").write_text(
            json.dumps(audit.results, indent=2),
            encoding="utf-8",
        )
        print(f"fatal: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(audit.results, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
