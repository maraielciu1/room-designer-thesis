#!/bin/bash
# One-time setup + run the Gaussian Splatting backend (Mac with msplat).
# Uses a virtual environment so we don't touch system Python.
# Prefers Python 3.12 or 3.13 (msplat has no wheel for 3.14 yet).
set -e
cd "$(dirname "$0")"
VENV_DIR=".venv"

echo "=== 1. Python ==="
# msplat often has no wheel for Python 3.14; prefer 3.12 or 3.13
PYTHON=""
for cand in python3.12 python3.13 python3; do
  if command -v "$cand" &>/dev/null; then
    MINOR=$("$cand" -c "import sys; print(sys.version_info.minor)" 2>/dev/null || true)
    if [ -n "$MINOR" ] && [ "$MINOR" -lt 14 ]; then
      PYTHON="$cand"
      break
    fi
    [ -z "$PYTHON" ] && PYTHON="$cand"
  fi
done
if [ -z "$PYTHON" ]; then
  echo "  Python 3 not found. Install: brew install python@3.12"
  exit 1
fi
PYVER=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "  Using $PYTHON ($PYVER)"
if [ "$PYVER" = "3.14" ]; then
  echo "  Note: msplat may not support 3.14 yet. If install fails, run: brew install python@3.12"
fi

echo ""
echo "=== 2. COLMAP ==="
if ! command -v colmap &>/dev/null; then
  echo "  COLMAP not found. Install with: brew install colmap"
  exit 1
fi
echo "  COLMAP found"

echo ""
echo "=== 3. Virtual environment ==="
if [ ! -d "$VENV_DIR" ]; then
  echo "  Creating $VENV_DIR with $PYTHON ..."
  "$PYTHON" -m venv "$VENV_DIR"
fi
echo "  Using $VENV_DIR"
PY="$VENV_DIR/bin/python"
PIP="$VENV_DIR/bin/pip"

echo ""
echo "=== 4. Pip packages ==="
"$PIP" install -q -r requirements.txt
if ! "$PIP" install -q msplat 2>/dev/null; then
  echo "  msplat install failed (common with Python 3.14 — no wheel yet)."
  echo ""
  echo "  Install Python 3.12, remove the venv, and re-run:"
  echo "    brew install python@3.12"
  echo "    rm -rf $VENV_DIR"
  echo "    ./setup_and_run.sh"
  echo ""
  exit 1
fi
echo "  flask + msplat installed"

echo ""
echo "=== 5. Setup check ==="
"$PY" check_setup.py

echo ""
echo "=== 6. Starting backend (Ctrl+C to stop) ==="
"$PY" app.py
