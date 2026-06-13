#!/usr/bin/env python3
"""Check that the backend can run (Python, COLMAP, msplat, Flask). Prints your Mac's IP for the app."""
import os
import shutil
import subprocess
import sys

import config

def ok(msg):
    print(f"  \033[92m✓\033[0m {msg}")

def fail(msg):
    print(f"  \033[91m✗\033[0m {msg}")

def main():
    print("Backend setup check\n")
    all_ok = True

    # Python 3.12+
    v = sys.version_info
    if v.major >= 3 and v.minor >= 12:
        ok(f"Python {v.major}.{v.minor}.{v.micro}")
    else:
        fail(f"Python 3.12+ required (you have {v.major}.{v.minor}.{v.micro})")
        all_ok = False

    # COLMAP
    colmap = shutil.which("colmap")
    if colmap:
        ok(f"COLMAP found: {colmap}")
    else:
        fail("COLMAP not found. Install: brew install colmap")
        all_ok = False

    # Flask
    try:
        import flask
        ver = getattr(flask, "__version__", "?")
        try:
            import importlib.metadata
            ver = importlib.metadata.version("flask")
        except Exception:
            pass
        ok(f"Flask {ver}")
    except ImportError:
        fail("Flask not installed. Run: pip install -r requirements.txt")
        all_ok = False

    # msplat (only on Mac)
    if sys.platform == "darwin":
        try:
            import msplat
            ok("msplat (Metal 3DGS) installed")
        except ImportError:
            fail("msplat not installed. Run: pip install msplat")
            all_ok = False
    else:
        print("  (msplat is Mac-only; on Linux use CUDA pipeline)")

    print()
    if not all_ok:
        print("Fix the issues above, then run again.")
        sys.exit(1)

    # Mac IP for the app
    if sys.platform == "darwin":
        try:
            out = subprocess.run(
                ["ipconfig", "getifaddr", "en0"],
                capture_output=True, text=True, timeout=2
            )
            ip = (out.stdout or "").strip()
            if ip:
                print("Use this Server URL in the app (same Wi‑Fi):")
                print(f"  \033[1mhttp://{ip}:{config.PORT}\033[0m")
            else:
                out2 = subprocess.run(
                    ["ipconfig", "getifaddr", "en1"],
                    capture_output=True, text=True, timeout=2
                )
                ip = (out2.stdout or "").strip()
                if ip:
                    print("Use this Server URL in the app (same Wi‑Fi):")
                    print(f"  \033[1mhttp://{ip}:{config.PORT}\033[0m")
                else:
                    print("Could not detect Wi‑Fi IP. Find it in System Settings -> Wi‑Fi -> your network.")
        except Exception:
            print("Could not detect Wi‑Fi IP. Find it in System Settings -> Wi‑Fi -> your network.")
    print()
    print("Ready. Start the backend with: python app.py")

if __name__ == "__main__":
    main()
