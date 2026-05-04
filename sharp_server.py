#!/usr/bin/env python3
"""
sharp_server.py
================
Local Flask server that wraps Apple's SHARP model for single-image
3D Gaussian Splatting inference.

Reference:
  Mescheder et al., "SHARP: Sharp Monocular View Synthesis", ICLR 2025
  https://machinelearning.apple.com/research/sharp-monocular-view
  https://github.com/apple/ml-sharp   ← clone this first

Usage:
  1.  Follow the STEP-BY-STEP section in this file.
  2.  conda activate sharp_env   (or: source .venv/bin/activate)
  3.  python sharp_server.py
  4.  In the app: My Furniture → + → SHARP — one photo splat → ⚙ → your Mac IP:
        http://<your-mac-local-ip>:8765

The iOS app sends:
  POST /sharp/infer   Content-Type: image/jpeg   Body: raw JPEG bytes
  GET  /health

The server replies with a raw binary .ply file (3DGS scene).
"""

# ─────────────────────────────────────────────────────────────────────────────
# STEP-BY-STEP SETUP
# ─────────────────────────────────────────────────────────────────────────────
#
# 1. CLONE THE SHARP REPOSITORY
#    Open Terminal on your Mac and run:
#
#      git clone https://github.com/apple/ml-sharp.git
#      cd ml-sharp
#
# 2. CREATE A PYTHON ENVIRONMENT (Python 3.10+ recommended)
#
#      python3 -m venv .venv
#      source .venv/bin/activate
#
# 3. INSTALL DEPENDENCIES
#    Inside the ml-sharp directory:
#
#      pip install -r requirements.txt
#      pip install flask pillow
#
#    If your Mac has Apple Silicon (M1/M2/M3/M4):
#      pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
#    Alternatively, PyTorch with MPS (Metal Performance Shaders) backend:
#      pip install torch torchvision
#
# 4. DOWNLOAD MODEL WEIGHTS
#    Follow the instructions in the ml-sharp README to download weights.
#    Typically:
#      python download_weights.py
#    or they are downloaded automatically on first run via Hugging Face Hub.
#
# 5. PLACE THIS FILE
#    Copy sharp_server.py into the ml-sharp directory (same level as the
#    sharp/ Python package), OR set SHARP_ROOT below to the absolute path.
#
# 6. FIND YOUR MAC'S LOCAL IP ADDRESS
#    System Settings → Wi-Fi → Details → IP Address
#    Or run in Terminal:  ipconfig getifaddr en0
#
# 7. RUN THE SERVER
#    Activate the SAME environment where you installed dependencies (critical):
#      conda activate sharp_env
#    or:
#      source .venv/bin/activate
#    Then from the ml-sharp directory:
#      python sharp_server.py
#    If you see "No module named 'flask'", you are using the wrong interpreter
#    (e.g. base conda) — switch to sharp_env / your venv first.
#    You should see:
#      Loading SHARP on mps...
#      ✅  SHARP ready
#      🚀  Server running at http://0.0.0.0:8765
#
# 8. CONFIGURE THE APP
#    In the iPhone app:
#      Rooms tab → ✦ button → ⚙ gear icon
#      Enter:  http://192.168.x.x:8765
#      Tap "Save & Check" — the badge should turn green.
#
# 9. INFO.PLIST ENTRIES REQUIRED IN XCODE
#    Open RoomScanTest/Info.plist and add:
#      NSCameraUsageDescription       "Used to capture a photo for SHARP 3D reconstruction"
#      NSLocalNetworkUsageDescription "Used to connect to the SHARP inference server on your local network"
#    (The project likely already has NSCameraUsageDescription from RoomPlan.)
#
# ─────────────────────────────────────────────────────────────────────────────

import io
import os
import sys
import traceback
from pathlib import Path

# ── Fail fast if the wrong Python env is active (e.g. conda base without Flask)
try:
    from flask import Flask, jsonify, request, send_file
except ModuleNotFoundError:
    sys.stderr.write(
        "\n❌  Flask is not installed for this Python interpreter.\n\n"
        "   Activate the environment where you set up ml-sharp, then retry, e.g.:\n"
        "     conda activate sharp_env\n"
        "   or:\n"
        "     source .venv/bin/activate\n"
        "   Then: pip install flask pillow\n"
        f"\n   Current Python: {sys.executable}\n\n"
    )
    raise SystemExit(1) from None

try:
    from PIL import Image
except ModuleNotFoundError:
    sys.stderr.write(
        "\n❌  Pillow is not installed. In your ml-sharp environment run:\n"
        "     pip install pillow\n\n"
    )
    raise SystemExit(1) from None

# ── Adjust if this script is NOT inside the ml-sharp directory ──────────────
SHARP_ROOT = Path(__file__).parent  # change to Path("/absolute/path/to/ml-sharp") if needed
sys.path.insert(0, str(SHARP_ROOT))

import torch

# ── Try to import SHARP ──────────────────────────────────────────────────────
#
# NOTE: The exact import path depends on the ml-sharp repo structure.
#       Check the README in the cloned repository and update accordingly.
#       Common patterns:
#         from sharp import SHARP
#         from sharp.model import SHARPModel
#         import sharp
#
try:
    from sharp import SHARP          # ← adjust if needed
    SHARP_AVAILABLE = True
except ImportError:
    SHARP_AVAILABLE = False
    print("⚠️  Could not import 'sharp'. Check that:")
    print(f"   • SHARP_ROOT is set correctly: {SHARP_ROOT}")
    print("   • You installed dependencies (pip install -r requirements.txt)")
    print("   • You are running inside the virtualenv")

# ── Flask app ────────────────────────────────────────────────────────────────

app = Flask(__name__)
_model = None
_device = None


def load_model() -> bool:
    """Load SHARP weights once at startup. Returns True on success."""
    global _model, _device
    if not SHARP_AVAILABLE:
        print("❌  SHARP module not available — server will run but /sharp/infer will return 503.")
        return False

    if torch.backends.mps.is_available():
        _device = "mps"
    elif torch.cuda.is_available():
        _device = "cuda"
    else:
        _device = "cpu"

    print(f"Loading SHARP on {_device}…")
    try:
        # ── ADJUST THIS CALL to match the ml-sharp API ──────────────────────
        # Option A (pretrained from HuggingFace Hub):
        _model = SHARP.from_pretrained("apple/sharp").to(_device).eval()
        #
        # Option B (local checkpoint):
        # _model = SHARP.load("path/to/checkpoint.pth").to(_device).eval()
        # ────────────────────────────────────────────────────────────────────
        print("✅  SHARP ready")
        return True
    except Exception:
        traceback.print_exc()
        print("❌  Failed to load SHARP weights.")
        return False


# ── Endpoints ────────────────────────────────────────────────────────────────

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "model_loaded": _model is not None,
        "device": _device,
        "sharp_available": SHARP_AVAILABLE,
    })


@app.route("/sharp/infer", methods=["POST"])
def infer():
    if _model is None:
        return jsonify({"error": "SHARP model not loaded. Check server logs."}), 503

    raw = request.data
    if not raw:
        return jsonify({"error": "No image data in request body."}), 400

    # Decode JPEG
    try:
        image = Image.open(io.BytesIO(raw)).convert("RGB")
    except Exception as e:
        return jsonify({"error": f"Failed to decode image: {e}"}), 400

    # Run SHARP inference
    try:
        with torch.no_grad():
            # ── ADJUST THIS CALL to match the ml-sharp API ──────────────
            # The model should accept a PIL Image (or tensor) and return
            # either raw .ply bytes or a path to the generated file.
            #
            # Option A — returns bytes directly:
            ply_bytes: bytes = _model.infer_to_ply(image)
            #
            # Option B — returns a file path:
            # ply_path = _model.infer(image, output_path="/tmp/sharp_out.ply")
            # with open(ply_path, "rb") as f:
            #     ply_bytes = f.read()
            # ─────────────────────────────────────────────────────────────
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"Inference failed: {e}"}), 500

    return send_file(
        io.BytesIO(ply_bytes),
        mimetype="application/octet-stream",
        download_name="sharp_result.ply",
    )


# ── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    load_model()
    port = int(os.environ.get("PORT", 8765))
    print(f"\n🚀  SHARP server running at http://0.0.0.0:{port}")
    print("    Set this URL in the app (⚙ icon):")
    print("    http://<your-mac-local-ip>:{port}\n")
    app.run(host="0.0.0.0", port=port, debug=False)
