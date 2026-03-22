#!/usr/bin/env python3
"""
Runs COLMAP + 3D Gaussian Splatting on a directory of images.
Input: path to a folder containing images (jpg, png, heic).
Output: path to the generated point_cloud.ply (or similar) in the same folder structure.

Requires: COLMAP and gaussian-splatting repo installed (see README).
"""
import os
import shutil
import subprocess
import sys
import tempfile

import config

# Timeouts (seconds) so a stuck COLMAP step fails instead of hanging forever.
COLMAP_FEATURE_TIMEOUT = 600   # 10 min for feature extraction
COLMAP_MATCH_TIMEOUT = 600    # 10 min for matching
COLMAP_MAP_TIMEOUT = 300      # 5 min for mapping


def _qt_plugin_path_darwin() -> str | None:
    """
    Find Qt plugin path on macOS. COLMAP links to qtbase (Qt 6), not the meta 'qt' formula.
    We must use qtbase's plugins so the version matches; otherwise Qt rejects them.
    """
    # qtbase: same Qt as COLMAP, plugins at share/qt/plugins
    for candidate in (
        "/opt/homebrew/opt/qtbase/share/qt/plugins",
        "/usr/local/opt/qtbase/share/qt/plugins",
    ):
        if os.path.isdir(os.path.join(candidate, "platforms")):
            return candidate
    # Fallback: meta qt (may be version mismatch)
    for candidate in (
        "/opt/homebrew/share/qt/plugins",
        "/usr/local/share/qt/plugins",
    ):
        if os.path.isdir(os.path.join(candidate, "platforms")):
            return candidate
    return None


def _colmap_env():
    """Build env dict used for COLMAP subprocess. On Darwin, set QT_PLUGIN_PATH so Qt finds cocoa."""
    env = os.environ.copy()
    if sys.platform == "darwin":
        plugin_path = _qt_plugin_path_darwin()
        if plugin_path:
            env["QT_PLUGIN_PATH"] = plugin_path
        if os.environ.get("SSH_CONNECTION"):
            env["QT_QPA_PLATFORM"] = "minimal"
            if not plugin_path:
                for candidate in (
                    "/opt/homebrew/opt/qt@5/plugins",
                    "/usr/local/opt/qt@5/plugins",
                ):
                    if os.path.isdir(os.path.join(candidate, "platforms")):
                        env["QT_PLUGIN_PATH"] = candidate
                        break
    return env


def _get_colmap_exe() -> str | None:
    """Return path to colmap. On Darwin we set QT_PLUGIN_PATH in env so Qt finds plugins."""
    return shutil.which(config.COLMAP_PATH) or (
        config.COLMAP_PATH if os.path.isfile(config.COLMAP_PATH) else None
    )


def check_colmap_ready() -> tuple[bool, str | None]:
    """Run COLMAP feature_extractor (loads Qt) so we fail at startup if Qt plugin is broken."""
    colmap_exe = _get_colmap_exe()
    if not colmap_exe:
        return False, "COLMAP not found. Install with: brew install colmap"

    env = _colmap_env()
    with tempfile.TemporaryDirectory(prefix="colmap_check_") as tmp:
        db = os.path.join(tmp, "db.db")
        img_dir = os.path.join(tmp, "img")
        os.makedirs(img_dir, exist_ok=True)
        try:
            r = subprocess.run(
                [colmap_exe, "feature_extractor", "--database_path", db, "--image_path", img_dir],
                env=env,
                capture_output=True,
                timeout=15,
                text=True,
            )
        except subprocess.TimeoutExpired:
            return False, "COLMAP check timed out. See MAC_SETUP.md."
        except Exception as e:
            return False, f"COLMAP check failed: {e}"

    out = (r.stdout or "") + (r.stderr or "")
    if "qt.qpa.plugin" in out or "no Qt platform plugin" in out or "Could not find the Qt platform plugin" in out:
        return False, (
            "COLMAP cannot start (Qt plugin). On Mac run: brew install qt. See MAC_SETUP.md."
        )
    return True, None


def run_colmap(images_dir: str, output_dir: str) -> str:
    """Run COLMAP to get sparse model and camera poses. Returns database path."""
    colmap_exe = _get_colmap_exe()
    if not colmap_exe:
        raise FileNotFoundError(
            f"COLMAP not found: {config.COLMAP_PATH}. Install with: brew install colmap"
        )

    os.makedirs(output_dir, exist_ok=True)
    db_path = os.path.join(output_dir, "database.db")
    sparse_path = os.path.join(output_dir, "sparse")
    os.makedirs(sparse_path, exist_ok=True)

    colmap_env = _colmap_env()
    if sys.platform == "darwin" and colmap_env.get("QT_PLUGIN_PATH"):
        print(f"[COLMAP] Using QT_PLUGIN_PATH={colmap_env['QT_PLUGIN_PATH']}")

    # Run COLMAP with stdout/stderr visible to avoid pipe deadlock and to see errors.
    def run_step(args, timeout, step_name):
        print(f"[COLMAP] {step_name}…")
        result = subprocess.run(
            [colmap_exe] + args,
            check=False,
            timeout=timeout,
            env=colmap_env,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"COLMAP {step_name} failed with exit code {result.returncode}. "
                "Check terminal output above for details."
            )

    # Feature extraction
    run_step(
        [
            "feature_extractor",
            "--database_path", db_path,
            "--image_path", images_dir,
        ],
        timeout=COLMAP_FEATURE_TIMEOUT,
        step_name="Feature extraction",
    )
    # Exhaustive matcher
    run_step(
        [
            "exhaustive_matcher",
            "--database_path", db_path,
        ],
        timeout=COLMAP_MATCH_TIMEOUT,
        step_name="Matching",
    )
    # Mapper
    run_step(
        [
            "mapper",
            "--database_path", db_path,
            "--image_path", images_dir,
            "--output_path", sparse_path,
        ],
        timeout=COLMAP_MAP_TIMEOUT,
        step_name="Mapping",
    )
    return db_path

def run_3dgs(source_dir: str, output_ply_path: str) -> None:
    """Run 3D Gaussian Splatting training. source_dir must contain images/ and sparse/0/ (COLMAP output)."""
    if not os.path.isdir(config.GS_PATH):
        raise FileNotFoundError(
            f"3DGS repo not found at {config.GS_PATH}. "
            "Set GS_PATH or clone https://github.com/graphdeco-inria/gaussian-splatting"
        )
    train_script = os.path.join(config.GS_PATH, "train.py")
    if not os.path.isfile(train_script):
        raise FileNotFoundError(
            f"No train.py at {train_script}. Point GS_PATH to the gaussian-splatting repo root."
        )
    # Official repo: python train.py -s <path> -i images (path must have sparse/0/ and images/)
    subprocess.run([
        sys.executable, train_script,
        "-s", source_dir,
        "-i", "images",
        "--eval",
    ], check=True, cwd=config.GS_PATH)
    # Output is under source_dir/point_cloud/iteration_XXXX/point_cloud.ply
    import shutil
    for root, _, files in os.walk(source_dir):
        for f in files:
            if f == "point_cloud.ply":
                shutil.copy(os.path.join(root, f), output_ply_path)
                return
    raise FileNotFoundError(f"No point_cloud.ply under {source_dir}")

def run(images_dir: str, output_ply_path: str, on_progress=None) -> None:
    """Full pipeline: COLMAP then 3DGS. images_dir = folder of images; output_ply_path = where to write result.
    We use job_dir = dirname(output_ply_path): COLMAP writes to job_dir (sparse/0), images stay in images_dir.
    We need a single 'source' dir with images/ + sparse/0 for train.py -s source -i images.
    """
    job_dir = os.path.dirname(output_ply_path)
    if on_progress:
        on_progress(5, "Running COLMAP…")
    # COLMAP writes to job_dir -> job_dir/sparse/0/
    run_colmap(images_dir, job_dir)
    # 3DGS expects one dir with images/ and sparse/0. We have job_dir/sparse/0 and images in images_dir.
    # So we need job_dir/images to exist. app.py extracts to job_dir/images already.
    source_dir = job_dir
    if on_progress:
        on_progress(40, "Running 3D Gaussian Splatting…")
    run_3dgs(source_dir, output_ply_path)
    if on_progress:
        on_progress(100, "Done")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python run_pipeline.py <images_dir> <output.ply>")
        sys.exit(1)
    run(sys.argv[1], sys.argv[2])
