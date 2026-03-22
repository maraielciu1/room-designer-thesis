# Gaussian Splatting Backend for RoomScanTest App

This backend receives a zip of images from the app, runs **COLMAP** (camera poses) + **3D Gaussian Splatting** (training), and returns a `.ply` file. The app then downloads the `.ply` and attaches it to the scanned object.

**On Mac:** The backend uses **msplat** (Metal) by default — no NVIDIA/CUDA needed. See [MAC_SETUP.md](MAC_SETUP.md) for install steps.

**Important:** Google Colab cannot be triggered by an external API. You have two options:

1. **Run this backend on your own server** (GPU VM, or your Mac with GPU) — the app uploads to your server, which runs the same pipeline as a Colab notebook.
2. **Run this Flask app inside Colab** and expose it with **ngrok** — then put the ngrok URL in the app. Colab acts as the "server" while the notebook is running.

---

## API (used by the app)

- **POST /jobs** — `multipart/form-data` with `file` = zip of images → `{ "jobId": "uuid" }`
- **GET /jobs/{id}/status** — `{ "status": "pending"|"processing"|"completed"|"failed", "progress": 0-100?, "message": "?" }`
- **GET /jobs/{id}/result** — returns binary `.ply` (only when status is `completed`)

---

## Option A: Run on a GPU server (recommended)

### 1. Install COLMAP and 3D Gaussian Splatting

On Ubuntu (GPU VM):

```bash
# COLMAP
sudo apt-get install colmap

# 3D Gaussian Splatting (clone and build)
git clone --recursive https://github.com/graphdeco-inria/gaussian-splatting
cd gaussian-splatting
# Install dependencies (Conda recommended), then build
```

See the [official 3DGS repo](https://github.com/graphdeco-inria/gaussian-splatting) for full install.

### 2. Set paths in `config.py`

Edit `config.py` and set:

- `COLMAP_PATH` — path to `colmap` executable
- `GS_PATH` — path to gaussian-splatting repo (for `train.py` and `convert.py`)

### 3. Run the Flask app

```bash
cd backend_3dgs
pip install flask gdown  # gdown only if using Replicate script
python app.py
```

Listen on 0.0.0.0 so the app can reach it:

```bash
flask --host 0.0.0.0 --port 5001 run
```

If the server is at `https://your-gpu-server.com`, in the app set **Server URL** to `https://your-gpu-server.com` (no trailing slash). If you put the app under a path, e.g. `https://your-server.com/gs`, set that.

---

## Option B: Run on your Mac (Apple Silicon, no NVIDIA)

Install COLMAP and msplat, then run the Flask app. The backend will use **msplat** (Metal) automatically. See **[MAC_SETUP.md](MAC_SETUP.md)** for step-by-step instructions.

## Option C: Run inside Google Colab (with ngrok)

1. Open a new Colab notebook (GPU runtime).
2. Install COLMAP and clone gaussian-splatting (see any "gaussian splatting colab" notebook).
3. Install Flask and pyngrok:
   ```python
   !pip install flask pyngrok
   ```
4. Upload this folder to Colab (or clone from your repo). Set `config.py` so `COLMAP_PATH` and `GS_PATH` point to the Colab paths (e.g. `/usr/local/bin/colmap`, `/content/gaussian-splatting`).
5. Run the Flask app and expose with ngrok:
   ```python
   from pyngrok import ngrok
   public_url = ngrok.connect(5001)
   print("Use this URL in the app:", public_url)
   # Then run: python app.py
   ```
6. In the app, set **Server URL** to the ngrok URL (e.g. `https://xxxx.ngrok.io`).

While the Colab tab is open and the app is running, the app can upload and get results. When you close Colab, the "server" stops.

---

## Option D: Use Replicate (no self-hosted GPU)

Replicate has models that take images and output a Gaussian splat (e.g. Trellis with `save_gaussian_ply: true`). You can run a **tiny proxy** that:

1. Receives the zip from the app (same POST /jobs API).
2. Unzips, uploads images to Replicate, runs the prediction.
3. Downloads the `.ply` from Replicate and serves it at GET /jobs/{id}/result.

See [Replicate Trellis](https://replicate.com/firtoz/trellis) and implement the same `/jobs` API in a serverless function (e.g. Cloud Run) that calls Replicate. Your API key stays on the server.

---

## App configuration

In the app, after saving a scanned object, enter your backend base URL in the **Server URL** field (e.g. `https://your-server.com` or the ngrok URL). Tap **Train in Cloud**. The app will:

1. Package the captured images into a zip and upload to `POST /jobs`.
2. Poll `GET /jobs/{id}/status` every few seconds.
3. When status is `completed`, download `GET /jobs/{id}/result` (the .ply) and attach it to the object.

No Google Colab "connection" is required — your backend (or Colab+ngrok) runs the same pipeline.
