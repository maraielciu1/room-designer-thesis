# Paths to COLMAP and 3D Gaussian Splatting. Adjust for your machine or Colab.
import os
import sys

# COLMAP executable (e.g. /usr/local/bin/colmap or just "colmap" if in PATH)
COLMAP_PATH = os.environ.get("COLMAP_PATH", "colmap")

# Root of the gaussian-splatting repo (CUDA; used only when USE_MSPLAT is False)
GS_PATH = os.environ.get("GS_PATH", os.path.expanduser("~/gaussian-splatting"))

# Where to store job data (temp dirs, zip, output .ply)
WORK_DIR = os.environ.get("GS_WORK_DIR", os.path.join(os.path.dirname(__file__), "work"))

# Use msplat (Metal, Apple Silicon) when True. On Mac we default to True so you don't need CUDA.
_use_msplat_env = os.environ.get("USE_MSPLAT", "").lower()
USE_MSPLAT = _use_msplat_env in ("1", "true", "yes") if _use_msplat_env else (sys.platform == "darwin")

# Port for the Flask server. Use 5001 to avoid conflict with macOS AirPlay Receiver (port 5000).
PORT = int(os.environ.get("GS_PORT", "5001"))
