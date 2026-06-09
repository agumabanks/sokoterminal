#!/usr/bin/env python3
"""Minimal adb/uiautomator feature walker for the seller terminal app."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path


PACKAGE = "com.soko24.soko_seller_terminal"
ACTIVITY = f"{PACKAGE}/{PACKAGE}.MainActivity"

MORE_TARGETS = [
    "Dashboard",
    "Reports",
    "Insights & Analytics",
    "Expenses",
    "Sanaa Wallet",
    "Customers",
    "Products",
    "Suppliers",
    "Purchase Orders",
    "Receive Stock",
    "Stock Count",
    "Low Stock",
    "Services",
    "Quotations",
    "Digital Catalog",
    "Wholesale & Digital",
    "Shifts & Cash",
    "Orders",
    "Auctions",
    "Refunds",
    "Ads & Creatives",
    "Bulk SMS",
    "Coupons",
    "Messages",
    "Business Setup",
    "Profile",
    "Shop Settings",
    "Verification",
    "Payment Settings",
    "Delivery Options",
    "Staff & Roles",
    "App Settings",
    "Receipt Templates",
    "Backup & Restore",
    "Sign Out",
]

SETTINGS_TARGETS = [
    "Choose printer",
    "Print queue",
    "Print diagnostics",
    "Test print",
    "Sync now",
    "Sync health",
    "Export",
    "Delivery settings",
    "Void reason codes",
    "Privacy policy",
]

TAB_TARGETS = ["Checkout", "Transactions", "Alerts", "More"]


def adb(*args: str, check: bool = True, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["adb", *args],
        check=check,
        text=True,
        capture_output=True,
        timeout=timeout,
    )


def sh(command: str, check: bool = True, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        shell=True,
        check=check,
        text=True,
        capture_output=True,
        timeout=timeout,
    )


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value or "screen"


def parse_bounds(bounds: str) -> tuple[int, int]:
    left, top, right, bottom = map(int, re.findall(r"\d+", bounds))
    return (left + right) // 2, (top + bottom) // 2


def unique_strings(root: ET.Element, limit: int = 18) -> list[str]:
    seen: list[str] = []
    for node in root.iter("node"):
        for attr in ("content-desc", "text"):
            raw = (node.attrib.get(attr) or "").strip()
            if not raw:
                continue
            text = raw.replace("\n", " | ")
            if text not in seen:
                seen.append(text)
        if len(seen) >= limit:
            break
    return seen[:limit]


class DeviceAudit:
    def __init__(self, outdir: Path, screenshots: bool, include_tabs: bool) -> None:
        self.outdir = outdir
        self.screenshots = screenshots
        self.include_tabs = include_tabs
        self.results: dict[str, object] = {
            "package": PACKAGE,
            "activity": ACTIVITY,
            "generated_at_epoch": int(time.time()),
            "screenshots": screenshots,
            "tabs": [],
            "features": [],
            "settings_subfeatures": [],
        }
        self.outdir.mkdir(parents=True, exist_ok=True)

    def log(self, message: str) -> None:
        print(message, flush=True)

    def write_json(self) -> None:
        path = self.outdir / "device-feature-audit.json"
        path.write_text(json.dumps(self.results, indent=2), encoding="utf-8")

    def dump_ui(self, stem: str) -> tuple[ET.Element, Path]:
        xml_path = self.outdir / f"{stem}.xml"
        with xml_path.open("wb") as handle:
            proc = subprocess.run(
                ["adb", "exec-out", "uiautomator", "dump", "/dev/tty"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=60,
            )
            handle.write(proc.stdout.replace(b"\r", b""))
        text = xml_path.read_text(encoding="utf-8", errors="ignore")
        if "null root node returned" in text:
            raise RuntimeError("uiautomator returned a null root node")
        end = text.rfind("</hierarchy>")
        if end == -1:
            raise RuntimeError("uiautomator dump did not contain a hierarchy root")
        clean = text[: end + len("</hierarchy>")]
        xml_path.write_text(clean, encoding="utf-8")
        return ET.fromstring(clean), xml_path

    def screenshot(self, stem: str) -> Path:
        path = self.outdir / f"{stem}.png"
        with path.open("wb") as handle:
            proc = subprocess.run(
                ["adb", "exec-out", "screencap", "-p"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=60,
            )
            handle.write(proc.stdout)
        return path

    def tap(self, x: int, y: int) -> None:
        adb("shell", "input", "tap", str(x), str(y))
        time.sleep(1.1)

    def back(self, count: int = 1) -> None:
        for _ in range(count):
            adb("shell", "input", "keyevent", "4")
            time.sleep(1)

    def swipe(self, start: tuple[int, int], end: tuple[int, int], duration_ms: int = 250) -> None:
        adb(
            "shell",
            "input",
            "swipe",
            str(start[0]),
            str(start[1]),
            str(end[0]),
            str(end[1]),
            str(duration_ms),
        )
        time.sleep(1.2)

    def find_node(self, root: ET.Element, query: str) -> ET.Element | None:
        query_lower = query.lower()
        for node in root.iter("node"):
            desc = (node.attrib.get("content-desc") or "").lower()
            text = (node.attrib.get("text") or "").lower()
            if query_lower in desc or query_lower in text:
                return node
        return None

    def wait_for(self, query: str, attempts: int = 10) -> ET.Element | None:
        for idx in range(attempts):
            try:
                root, _ = self.dump_ui(f"wait-{slugify(query)}-{idx}")
            except Exception:
                time.sleep(1)
                continue
            node = self.find_node(root, query)
            if node is not None:
                return node
            time.sleep(1)
        return None

    def wait_for_ready(self, attempts: int = 20) -> None:
        for idx in range(attempts):
            try:
                root, _ = self.dump_ui(f"ready-check-{idx}")
            except Exception:
                time.sleep(2)
                continue
            if self.find_node(root, "Checking staff session") is not None:
                time.sleep(2)
                continue
            if self.find_node(root, "Checkout") is not None or self.find_node(root, "More") is not None:
                return
            time.sleep(2)
        raise RuntimeError("app did not reach a ready post-session screen")

    def open_tab(self, label: str) -> bool:
        root, _ = self.dump_ui(f"tab-before-{slugify(label)}")
        node = self.find_node(root, label)
        if node is None:
            return False
        x, y = parse_bounds(node.attrib["bounds"])
        self.tap(x, y)
        time.sleep(2)
        return True

    def reset_more_to_top(self) -> None:
        self.open_tab("More")
        for _ in range(6):
            self.swipe((400, 250), (400, 1080))

    def scroll_find_more(self, label: str, max_swipes: int = 8) -> ET.Element | None:
        self.reset_more_to_top()
        for idx in range(max_swipes + 1):
            root, _ = self.dump_ui(f"more-search-{slugify(label)}-{idx}")
            node = self.find_node(root, label)
            if node is not None:
                return node
            self.swipe((400, 1030), (400, 260))
        return None

    def record_screen(self, bucket: str, label: str, stem_prefix: str) -> dict[str, object]:
        time.sleep(2)
        stem = f"{stem_prefix}-{slugify(label)}"
        root, xml_path = self.dump_ui(stem)
        screen = {
            "label": label,
            "status": "opened",
            "xml": str(xml_path),
            "strings": unique_strings(root),
        }
        if self.screenshots:
            screen["png"] = str(self.screenshot(stem))
        self.results[bucket].append(screen)  # type: ignore[index]
        return screen

    def inspect_tab(self, label: str) -> None:
        self.log(f"TAB {label}")
        ok = self.open_tab(label)
        if not ok:
            self.results["tabs"].append({"label": label, "status": "missing-tab"})
            return
        self.record_screen("tabs", label, "tab")

    def inspect_more_target(self, label: str) -> None:
        self.log(f"FEATURE {label}")
        node = self.scroll_find_more(label)
        if node is None:
            self.results["features"].append({"label": label, "status": "not-found-in-runtime-menu"})
            return
        x, y = parse_bounds(node.attrib["bounds"])
        self.tap(x, y)
        self.record_screen("features", label, "feature")
        self.back()
        self.wait_for("More")

    def inspect_settings_subtargets(self) -> None:
        self.log("FEATURE App Settings (nested)")
        node = self.scroll_find_more("App Settings")
        if node is None:
            self.results["settings_subfeatures"].append(
                {"label": "App Settings", "status": "not-found-in-runtime-menu"}
            )
            return
        x, y = parse_bounds(node.attrib["bounds"])
        self.tap(x, y)
        self.record_screen("settings_subfeatures", "App Settings", "settings-root")
        for label in SETTINGS_TARGETS:
            self.log(f"SETTINGS {label}")
            root, _ = self.dump_ui(f"settings-search-{slugify(label)}")
            node = self.find_node(root, label)
            if node is None:
                self.results["settings_subfeatures"].append(
                    {"label": label, "status": "not-found-on-settings-screen"}
                )
                continue
            x, y = parse_bounds(node.attrib["bounds"])
            self.tap(x, y)
            self.record_screen("settings_subfeatures", label, "settings")
            self.back()
            self.wait_for("Settings")
        self.back()
        self.wait_for("More")

    def run(self) -> None:
        self.log("START")
        adb("shell", "am", "start", "-n", ACTIVITY)
        self.wait_for_ready()
        if self.include_tabs:
            for label in TAB_TARGETS:
                self.inspect_tab(label)
        for label in MORE_TARGETS:
            self.inspect_more_target(label)
        self.inspect_settings_subtargets()
        self.write_json()
        self.log("DONE")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--outdir",
        default="/var/www/soko/artifacts/device-audit",
        help="Directory for XML, screenshots, and JSON summary.",
    )
    parser.add_argument(
        "--screenshots",
        action="store_true",
        help="Capture PNG screenshots in addition to XML dumps.",
    )
    parser.add_argument(
        "--skip-tabs",
        action="store_true",
        help="Skip the bottom tab captures and walk the More menu only.",
    )
    args = parser.parse_args(argv)
    audit = DeviceAudit(
        Path(args.outdir),
        screenshots=args.screenshots,
        include_tabs=not args.skip_tabs,
    )
    try:
        audit.run()
    except Exception as exc:  # pragma: no cover - runtime harness
        audit.results["fatal_error"] = str(exc)
        audit.write_json()
        print(f"fatal: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(audit.results, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
