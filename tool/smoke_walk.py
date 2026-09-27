#!/usr/bin/env python3
"""Automated UI smoke walk of the running Soko Seller Terminal on a real device.

Drives the app via adb: taps bottom-nav tabs, opens tool screens, asserts the
expected heading text is present, screenshots each step, and fails loudly on
any crash / Flutter error.
"""
import os
import html
import re
import subprocess
import sys
import time

PKG = "com.soko24.soko_seller_terminal"
ACTIVITY = f"{PKG}/.MainActivity"
PKGSET = "soko24u.buyer"  # noise filter
OUT = "/var/www/soko/app/soko_seller_terminal/build/smoke"
ADB = ["adb"]


def sh(*args, timeout=120):
    return subprocess.run(list(ADB) + list(args), capture_output=True,
                          text=True, timeout=timeout)


def shell(cmd, timeout=120):
    return sh("shell", cmd, timeout=timeout)


def dump_ui():
    """Return list of (text, content_desc, bounds) for visible nodes."""
    for attempt in range(3):
        shell("rm -f /sdcard/ui.xml")
        r = sh("shell", "uiautomator dump /sdcard/ui.xml")
        if "dumped to" in (r.stdout or "") or "UI hierchary" in (r.stdout or ""):
            xml = sh("shell", "cat /sdcard/ui.xml", timeout=180).stdout
            if "<hierarchy" in (xml or ""):
                return xml
        time.sleep(2)
    return ""


def texts(xml):
    out = []
    for m in re.finditer(r'text="([^"]*)"', xml):
        t = html.unescape(m.group(1)).strip()
        if t and t not in out:
            out.append(t)
    for m in re.finditer(r'content-desc="([^"]*)"', xml):
        t = html.unescape(m.group(1)).strip()
        if t and t not in out:
            out.append(t)
    return out


def find_node(xml, needle, min_y=0):
    """Return (cx, cy) center of first node whose text/content-desc contains needle."""
    for m in re.finditer(r'<node[^>]*>', xml):
        tag = m.group(0)
        text = re.search(r'text="([^"]*)"', tag)
        desc = re.search(r'content-desc="([^"]*)"', tag)
        hay = f"{text.group(1) if text else ''} {desc.group(1) if desc else ''}"
        if needle.lower() in hay.lower():
            b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
            if b:
                x1, y1, x2, y2 = map(int, b.groups())
                if y1 < min_y:
                    continue
                return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def nav_bar_y(xml):
    """Vertical midpoint of the bottom navigation bar."""
    best = None
    for m in re.finditer(r'<node[^>]*>', xml):
        tag = m.group(0)
        vals = [html.unescape(v).strip()
                for v in re.findall(r'(?:text|content-desc)="([^"]*)"', tag)]
        # A nav item is a node whose content-desc is exactly the label
        # (no "99+" badge suffix, no page text) near the bottom of the screen.
        if not any(v.lower() in ("sell", "today", "alerts", "me") for v in vals):
            continue
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
        if b:
            _, y1, _, y2 = map(int, b.groups())
            if y1 < 1000:
                continue
            y = (y1 + y2) // 2
            best = y if best is None else max(best, y)
    return best if best else 1175


def go_tab(xml, label):
    """Tap a bottom-nav tab by geometry so page text can never shadow it."""
    y = nav_bar_y(xml)
    pt = find_node(xml, label, min_y=y - 5)
    if not pt:
        return None
    tap(pt[0], y)
    return pt


def tap(x, y):
    shell(f"input tap {x} {y}")
    time.sleep(1.5)


def tap_text(xml, needle):
    pt = find_node(xml, needle)
    if pt:
        tap(*pt)
        return True
    return False


def shot(name):
    os.makedirs(OUT, exist_ok=True)
    sh("shell", f"screencap -p /sdcard/{name}.png")
    sh("pull", f"/sdcard/{name}.png", f"{OUT}/{name}.png")
    return f"{OUT}/{name}.png"


def back():
    shell("input keyevent 4")
    time.sleep(1.2)


def restart_app(settle=75):
    """Cold-start the app and wait until it actually paints the POS screen.

    The first boot after install runs Drift migrations and a full sync, which
    on this device takes well over the usual 10s. Poll the UI tree until the
    POS screen appears instead of sleeping a fixed amount.
    """
    shell(f"am force-stop {PKG}")
    time.sleep(2)
    shell(f"am start -n {ACTIVITY}")
    deadline = time.time() + settle
    while time.time() < deadline:
        time.sleep(3)
        xml = dump_ui()
        if "Point of Sale" in texts(xml):
            return xml
    return ""


def logcat_tail(n=250):
    r = shell(f"logcat -d -t {n} {PKG}:V flutter:V '*:S'", timeout=180)
    return (r.stdout or "") + (r.stderr or "")


FAILURES = []
STEPS = []


def step(name, ok, detail=""):
    STEPS.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  -- {detail}" if detail else ""),
          flush=True)
    if not ok:
        FAILURES.append(f"{name}: {detail}")
    return ok


def dismiss_sheets(xml):
    """Close any modal sheet blocking the page so tiles are reachable."""
    for label in ["Close", "Dismiss"]:
        pt = find_node(xml, label)
        if pt:
            tap(*pt)
            time.sleep(1.5)
            return True
    return False


def main():
    shell("input keyevent KEYCODE_WAKEUP")
    shell("wm dismiss-keyguard || true")
    xml = restart_app()
    t = texts(xml)
    assert "Point of Sale" in t, f"app did not reach POS: {t[:20]}"
    step("cold start reaches POS screen", True, ", ".join(t[:4]))
    shot("01-pos")

    # Bottom nav (geometry-based so page text cannot shadow the tab)
    for tab in ["Today", "Alerts", "Me"]:
        xml = dump_ui()
        dismiss_sheets(xml)
        xml = dump_ui()
        if not step(f"tap bottom nav: {tab}", go_tab(xml, tab) is not None):
            continue
        time.sleep(2.5)
        xml2 = dump_ui()
        t2 = texts(xml2)
        if tab == "Today":
            ok = any(x in " ".join(t2) for x in ["Today", "Sales", "Orders"])
        elif tab == "Alerts":
            ok = any(x in " ".join(t2) for x in ["Alert", "Notification", "Stock"])
        else:
            ok = any(x in " ".join(t2) for x in ["Me", "Settings", "Account", "Sign out"])
        step(f"{tab} tab renders", ok, ", ".join(t2[:6]))
        shot(f"02-{tab.lower()}")
        xml = xml2

    # Me tab tool tiles
    xml = dump_ui()
    dismiss_sheets(xml)
    go_tab(xml, "Me")
    time.sleep(2.5)
    for label, expect in [("Products", "Product"), ("Customers", "Customer"),
                          ("Orders", "Order"), ("Payment Links", "Payment"),
                          ("Studio", "Studio"), ("Analytics", "Analytic")]:
        xml = dump_ui()
        if dismiss_sheets(xml):
            xml = dump_ui()
        pt = find_node(xml, label)
        if pt is None:
            step(f"Me > {label}", False, "tile not found in Me tab")
            continue
        tap(*pt)
        time.sleep(3.5)
        xml2 = dump_ui()
        t2 = texts(xml2)
        hit = expect and any(expect.lower() in x.lower() for x in t2)
        step(f"Me > {label} opens", hit, ", ".join(t2[:5]))
        shot(f"03-{label.replace(' ', '_').lower()}")
        back()
        time.sleep(2)
        dismiss_sheets(dump_ui())
        go_tab(dump_ui(), "Me")
        time.sleep(2)

    log = logcat_tail()
    step("no Flutter exceptions in logcat", "EXCEPTION CAUGHT" not in log,
         "clean" if "EXCEPTION CAUGHT" not in log else "flutter error present")
    pid = sh("shell", f"pidof {PKG}").stdout.strip()
    step("process still alive", pid != "", pid)
    shot("99-final")

    print("\n===== SUMMARY =====")
    ok = sum(1 for _, o, _ in STEPS if o)
    print(f"{ok}/{len(STEPS)} steps passed")
    for n, o, d in STEPS:
        if not o:
            print(f"  FAIL {n}  {d}")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
