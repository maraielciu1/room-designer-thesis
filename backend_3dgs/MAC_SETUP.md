# Running 3D Gaussian Splatting on a Mac (No NVIDIA/CUDA)

The **official** [graphdeco-inria/gaussian-splatting](https://github.com/graphdeco-inria/gaussian-splatting) repo is **CUDA-only** and requires an NVIDIA GPU. It will **not** run natively on a Mac (Intel or Apple Silicon).

You can still train Gaussian Splats on your Mac using one of these alternatives.

---

## Option 1: **gsplat-mps** (PyTorch + MPS on Apple Silicon)

- **Repo:** [iffyloop/gsplat-mps](https://github.com/iffyloop/gsplat-mps)
- **What it is:** Metal Performance Shaders (MPS) port of the gsplat library so the rasterization runs on Apple GPU. Works with PyTorch’s MPS backend.
- **Good for:** Apple Silicon Macs (M1/M2/M3/M4). You can run a training script similar to the original pipeline.
- **Install:** Clone the repo and follow its README (typically `pip install -e .` and PyTorch with MPS). Use their example trainer with your COLMAP output.

You still need **COLMAP** for camera poses. COLMAP runs on Mac (no GPU required for the CPU version):

```bash
brew install colmap
```

So on Mac you can: (1) run COLMAP on your images (CPU), (2) run gsplat-mps training (Apple GPU via MPS).

---

## Option 2: **msplat** (integrated with this backend)

**msplat** is a full Metal 3D Gaussian Splatting engine for Apple Silicon (~70–90 s training on M4 Max). This backend **uses msplat automatically on Mac** so you don’t need NVIDIA or CUDA.

### 1. Install COLMAP and Python 3.12 or 3.13

```bash
brew install colmap
brew install python@3.12   # msplat has no wheel for Python 3.14 yet; 3.12 or 3.13 required
```

**Note:** COLMAP uses Qt (pulled in by `brew install colmap`). The backend sets `QT_PLUGIN_PATH` so Qt finds the “cocoa” plugin. If you see *"Could not find the Qt platform plugin"*, ensure qtbase is installed: `brew install qtbase` (usually already installed with colmap) (then restart the backend). When running over SSH, headless Qt may not work; run the backend from Terminal.app on the Mac instead.

The setup script will use `python3.12` if available. If you only have Python 3.14 and msplat fails to install, install 3.12 as above, then `rm -rf backend_3dgs/.venv` and run `./setup_and_run.sh` again.

### 2. Install the backend and msplat

```bash
cd backend_3dgs
pip install -r requirements.txt
pip install msplat
```

### 3. Run the backend

```bash
python app.py
# Or: flask --host 0.0.0.0 --port 5001 run
```

On **Darwin (macOS)**, the app uses **msplat** by default: it runs COLMAP on the uploaded images, then trains with msplat and returns the `.ply`. No CUDA or GPU server needed.

### 4. Use from the iOS app

- On your Mac, the backend is reachable at `http://<your-mac-ip>:5001` from the iPhone (same Wi‑Fi). Or use **ngrok** to expose it: `ngrok http 5000` and put the ngrok URL in the app’s **Server URL**.
- In the app, set **Server URL** to that address (e.g. `http://192.168.1.x:5001` or `https://xxxx.ngrok.io`), then tap **Train in Cloud** after saving a scan.

### Override (use CUDA pipeline on Mac)

If you have the CUDA gaussian-splatting repo and want to use it even on Mac (e.g. via a remote GPU), set:

```bash
export USE_MSPLAT=0
python app.py
```

---

## Option 3: **Don’t run training on your Mac**

- Use **Google Colab** (free GPU) with the official CUDA repo: upload your images, run the notebook, download the `.ply`. Your app can still use “Export images” and then you train in Colab and “Import .ply” in the app.
- Or run the **backend** (from this project) on a **cloud GPU** (e.g. RunPod, Lambda Labs, GCP) with the official repo installed there. The app uploads to your backend and gets the `.ply` back.

---

## Summary

| Option              | Runs on Mac? | Needs NVIDIA? | Notes                          |
|---------------------|-------------|---------------|---------------------------------|
| Official 3DGS repo  | No          | Yes (CUDA)    | Use Colab or a cloud GPU       |
| **gsplat-mps**      | Yes (M1+)   | No            | COLMAP on Mac + MPS training   |
| **msplat**          | Yes (M1+)   | No            | Full Metal pipeline on Mac     |
| Colab / cloud GPU   | N/A         | Yes (in cloud)| Use from Mac, train in cloud   |

So: **you cannot install and run the original gaussian-splatting repo on your Mac** because of CUDA. You **can** install and run **gsplat-mps** or **msplat** on your Mac for training without any NVIDIA hardware.
