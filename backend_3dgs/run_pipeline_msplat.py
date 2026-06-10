#!/usr/bin/env python3
"""
Pipeline using msplat (Metal 3D Gaussian Splatting for Apple Silicon).
Same as run_pipeline.py but trains with msplat instead of the CUDA repo.
Requires: COLMAP (brew install colmap), msplat (pip install msplat).
"""
import os
import sys

import config

# Reuse COLMAP step from the main pipeline
from run_pipeline import run_colmap


def convert_heic_to_jpg(images_dir: str) -> None:
    """Convert HEIC/HEIF files to JPG in place so COLMAP can read them. Uses macOS sips."""
    import subprocess
    import glob
    for path in glob.glob(os.path.join(images_dir, "*.[hH][eE][iI][cC]")) + glob.glob(os.path.join(images_dir, "*.[hH][eE][iI][fF]")):
        out = os.path.splitext(path)[0] + ".jpg"
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "best", path, "--out", out], check=True, capture_output=True)
        os.remove(path)


def run_msplat_training(colmap_dir: str, output_ply_path: str, on_progress=None) -> None:
    """Train with msplat and export .ply. colmap_dir must contain images/ and sparse/0/."""
    try:
        import msplat
    except ImportError:
        raise ImportError(
            "msplat is not installed. On Mac run: pip install msplat"
        ) from None

    if on_progress:
        on_progress(45, "Loading dataset…")
    dataset = msplat.load_dataset(colmap_dir, eval_mode=True)
    cfg = msplat.TrainingConfig(
        iterations=7000,
        num_downscales=2,
        downscale_factor=2.0,
        densify_grad_thresh=0.0005,  # prevent Gaussian count explosion
        stop_screen_size_at=3000,    # stop densification at step 3000
    )
    trainer = msplat.GaussianTrainer(dataset, cfg)

    last_pct = [45]  # mutable so callback can update

    def step_callback(stats):
        # stats has .iteration, .splat_count
        pct = 45 + int(55 * stats.iteration / cfg.iterations)
        if pct > last_pct[0] and on_progress:
            last_pct[0] = pct
            on_progress(min(pct, 99), f"Training… step {stats.iteration}/{cfg.iterations}")

    if on_progress:
        on_progress(50, "Training (Metal)…")
    trainer.train(step_callback, callback_every=100)

    if on_progress:
        on_progress(98, "Exporting .ply…")
    trainer.export_ply(output_ply_path)
    checkpoint_path = os.path.splitext(output_ply_path)[0] + "_checkpoint.bin"
    trainer.save_checkpoint(checkpoint_path)


def run(images_dir: str, output_ply_path: str, on_progress=None) -> None:
    """Full pipeline: COLMAP then msplat. Same I/O contract as run_pipeline.run()."""
    job_dir = os.path.dirname(output_ply_path)
    if on_progress:
        on_progress(2, "Converting HEIC→JPG if needed…")
    print("[Pipeline] Converting HEIC→JPG if needed…")
    convert_heic_to_jpg(images_dir)
    if on_progress:
        on_progress(5, "Running COLMAP…")
    print("[Pipeline] Running COLMAP (this can take 2–10+ min depending on image count)…")
    run_colmap(images_dir, job_dir)
    print("[Pipeline] COLMAP done. Starting msplat…")
    # job_dir now has images/ and sparse/0/ (COLMAP format msplat expects)
    if on_progress:
        on_progress(40, "Starting msplat (Metal)…")
    run_msplat_training(job_dir, output_ply_path, on_progress=on_progress)
    if on_progress:
        on_progress(100, "Done")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python run_pipeline_msplat.py <images_dir> <output.ply>")
        sys.exit(1)
    run(sys.argv[1], sys.argv[2])
