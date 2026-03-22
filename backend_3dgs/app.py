"""
Flask backend for the RoomScanTest app's "Train in Cloud" feature.
Receives a zip of images, runs COLMAP + 3DGS (via run_pipeline), returns .ply.

The pipeline runs in a separate process so Flask stays responsive and status
requests return immediately (no timeout on the phone).
"""
import json
import os
import shutil
import sys
import threading
import uuid
import zipfile
from pathlib import Path

import config

# Check COLMAP (and Qt on Mac) before accepting jobs.
from run_pipeline import check_colmap_ready
ok, err = check_colmap_ready()
if not ok:
    print("\n*** COLMAP check failed — pipeline would fail on first job ***")
    print(err)
    print("Fix the issue above, then restart the server.\n")
    sys.exit(1)

from multiprocessing import Process

from flask import Flask, request, jsonify, send_file

app = Flask(__name__)
os.makedirs(config.WORK_DIR, exist_ok=True)

# job_id -> { "status", "progress", "message", "result_path", "job_dir" }
jobs = {}
jobs_lock = threading.Lock()

PROGRESS_FILE = "progress.json"


def _write_progress(job_dir: str, status: str, progress: int, message: str | None) -> None:
    path = os.path.join(job_dir, PROGRESS_FILE)
    with open(path, "w") as f:
        json.dump({"status": status, "progress": progress, "message": message}, f)


def _run_pipeline_subprocess(job_id: str, zip_path: str, job_dir: str) -> None:
    """Runs in a separate process so Flask is never blocked. Writes progress to job_dir/progress.json."""
    result_ply = os.path.join(job_dir, "result.ply")
    try:
        print(f"[Job {job_id[:8]}] Unzipping…")
        _write_progress(job_dir, "processing", 0, "Unzipping…")
        extract_dir = os.path.join(job_dir, "images")
        os.makedirs(extract_dir, exist_ok=True)
        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(extract_dir)
        def count_images(d):
            return sum(1 for f in os.listdir(d) if os.path.isfile(os.path.join(d, f)) and f.lower().endswith((".jpg", ".jpeg", ".png", ".heic")))
        best_dir = extract_dir
        for root, dirs, _ in os.walk(extract_dir):
            for d in dirs:
                sub = os.path.join(root, d)
                if count_images(sub) > count_images(best_dir):
                    best_dir = sub
        if os.path.abspath(best_dir) != os.path.abspath(extract_dir):
            for f in os.listdir(best_dir):
                src = os.path.join(best_dir, f)
                if os.path.isfile(src) and f.lower().endswith((".jpg", ".jpeg", ".png", ".heic")):
                    shutil.move(src, os.path.join(extract_dir, os.path.basename(f)))
        images_dir = extract_dir

        def on_progress(pct, msg):
            _write_progress(job_dir, "processing", pct, msg)

        if config.USE_MSPLAT:
            from run_pipeline_msplat import run
        else:
            from run_pipeline import run
        print(f"[Job {job_id[:8]}] Starting pipeline (COLMAP → msplat)…")
        run(images_dir, result_ply, on_progress=on_progress)
        print(f"[Job {job_id[:8]}] Pipeline finished.")
        _write_progress(job_dir, "completed", 100, "Done")
    except Exception as e:
        print(f"[Job {job_id[:8]}] Pipeline failed: {e}")
        _write_progress(job_dir, "failed", 0, str(e))


def _wait_subprocess_and_update(job_id: str, job_dir: str, proc: Process) -> None:
    proc.join()
    result_ply = os.path.join(job_dir, "result.ply")
    progress_path = os.path.join(job_dir, PROGRESS_FILE)
    with jobs_lock:
        if job_id not in jobs:
            return
        try:
            if os.path.isfile(progress_path):
                with open(progress_path) as f:
                    data = json.load(f)
                jobs[job_id]["status"] = data["status"]
                jobs[job_id]["progress"] = data.get("progress", 0)
                jobs[job_id]["message"] = data.get("message")
                if data["status"] == "completed" and os.path.isfile(result_ply):
                    jobs[job_id]["result_path"] = result_ply
        except Exception:
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["message"] = "Pipeline exited"


@app.route("/jobs", methods=["POST"])
def create_job():
    if "file" not in request.files:
        return jsonify({"error": "No file"}), 400
    f = request.files["file"]
    if f.filename == "":
        return jsonify({"error": "No file"}), 400
    job_id = str(uuid.uuid4())
    job_dir = os.path.join(config.WORK_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)
    zip_path = os.path.join(job_dir, "upload.zip")
    f.save(zip_path)
    with jobs_lock:
        jobs[job_id] = {"status": "processing", "progress": 0, "message": "Starting…", "result_path": None, "job_dir": job_dir}
    proc = Process(target=_run_pipeline_subprocess, args=(job_id, zip_path, job_dir))
    proc.start()
    t = threading.Thread(target=_wait_subprocess_and_update, args=(job_id, job_dir, proc), daemon=True)
    t.start()
    return jsonify({"jobId": job_id}), 201


@app.route("/jobs/<job_id>/status", methods=["GET"])
def job_status(job_id):
    with jobs_lock:
        if job_id not in jobs:
            return jsonify({"error": "Job not found"}), 404
        j = jobs[job_id].copy()
    job_dir = j.get("job_dir")
    progress_path = job_dir and os.path.join(job_dir, PROGRESS_FILE)
    # Read live progress from file so we respond instantly (pipeline runs in another process).
    if j["status"] == "processing" and progress_path and os.path.isfile(progress_path):
        try:
            with open(progress_path) as f:
                data = json.load(f)
            return jsonify({
                "status": data["status"],
                "progress": data.get("progress"),
                "message": data.get("message"),
            })
        except Exception:
            pass
    return jsonify({
        "status": j["status"],
        "progress": j.get("progress"),
        "message": j.get("message"),
    })


@app.route("/jobs/<job_id>/result", methods=["GET"])
def job_result(job_id):
    with jobs_lock:
        if job_id not in jobs:
            return jsonify({"error": "Job not found"}), 404
        path = jobs[job_id].get("result_path")
        if not path or jobs[job_id]["status"] != "completed":
            return jsonify({"error": "Not ready"}), 404
    if not os.path.isfile(path):
        return jsonify({"error": "Result file missing"}), 404
    return send_file(path, mimetype="application/octet-stream", as_attachment=True, download_name="point_cloud.ply")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=config.PORT, debug=True)
