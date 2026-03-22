# Set Up and Test Gaussian Splatting (Train in Cloud)

Follow these steps to run the app and confirm the full pipeline works.

---

## Part 1: Backend on your Mac

### 1.1 Install COLMAP (if not already)

```bash
brew install colmap
```

### 1.2 Open Terminal and go to the backend folder

```bash
cd /Users/maraielciu/Desktop/RoomScanTest/backend_3dgs
```

### 1.3 Run the setup script (installs Python deps and checks everything)

```bash
chmod +x setup_and_run.sh
./setup_and_run.sh
```

- The first time it will create a **virtual environment** (`.venv`) in `backend_3dgs` and install `flask` and `msplat` there (so system Python is not modified), then run a quick check.
- If something is missing (e.g. Python &lt; 3.12 or COLMAP not found), it will tell you. Fix that and run again.
- At the end it will **start the Flask server** and print something like:
  - `* Running on http://0.0.0.0:5001`

**Leave this terminal window open** so the backend keeps running.

### 1.4 Get the Server URL for the app

In the same terminal, the script should have printed a line like:

```text
Use this Server URL in the app (same Wi‑Fi):
  http://192.168.1.5:5001
```

Copy that URL (use your actual IP). If you didn’t see it, run in another terminal:

```bash
cd /Users/maraielciu/Desktop/RoomScanTest/backend_3dgs
python3 check_setup.py
```

It will print the URL again.

---

## Part 2: Run the iOS app

### 2.1 Open the project in Xcode

```bash
open /Users/maraielciu/Desktop/RoomScanTest/RoomScanTest.xcodeproj
```

### 2.2 Build and run on a real device (recommended)

- Connect your **iPhone** (same Wi‑Fi as your Mac).
- Select your iPhone as the run destination.
- Press **Run** (▶) to build and install the app.

Using the **Simulator** is possible, but Object Capture and “Train in Cloud” are meant for a real device with a camera and network.

### 2.3 Set the Server URL in the app

You’ll set this **after** your first scan, on the “Done” screen. For the test flow below, have the URL ready (e.g. `http://192.168.1.5:5001`).

---

## Part 3: Test the full Gaussian splatting flow

### 3.1 Scan an object

1. In the app, go to **Furniture Library** (or the entry that opens object scanning).
2. Start a **new object scan** (e.g. “Scan new object” or similar).
3. Follow the prompts: point at an object, walk around it so you get **at least 20–30 images** from different angles.
4. When done, tap **Finish Scan** and wait for reconstruction (Object Capture USDZ).
5. **Name** the object and pick a **category**, then tap **Save to My Furniture**.

### 3.2 Train in Cloud

1. On the **Done** screen you should see:
   - **Server URL** (text field)
   - **Train in Cloud** (button)
2. In **Server URL**, enter the URL from Part 1.4 (e.g. `http://192.168.1.5:5001`) — **no trailing slash**.
3. Tap **Train in Cloud**.
4. You should see:
   - “Packaging images…”
   - “Uploading…”
   - “Training… X%” (for a minute or two)
   - Then “Done! Splat attached to …” or the dialog dismissing.

If you see an error (e.g. “Upload failed” or “Connection refused”), check:

- Backend is still running in the terminal.
- iPhone and Mac are on the **same Wi‑Fi**.
- Server URL is exactly like `http://<Mac-IP>:5001` (no `https`, no trailing slash).

### 3.3 Check that Gaussian splatting worked

1. Go to **Furniture Library** and open the object you just scanned.
2. You should see options to view **Object Capture** (USDZ) and **Gaussian Splat** (or “Import .ply Splat” if the UI shows that).
3. If the splat was attached successfully, open the **Gaussian Splat** view (or **Reconstruction Comparison** for side‑by‑side). You should see the 3D Gaussian reconstruction of the same object.

---

## Quick reference

| Step              | Where                    | What to do                                      |
|-------------------|--------------------------|-------------------------------------------------|
| Start backend     | Terminal, `backend_3dgs` | `./setup_and_run.sh` (keep it running)         |
| Server URL        | Printed by script        | Copy e.g. `http://192.168.1.5:5001`            |
| Set URL in app    | Done screen after save   | Paste URL, then tap **Train in Cloud**         |
| See result        | Furniture Library → item | Open item → Gaussian Splat / Comparison view   |

---

## If something fails

- **“No module named 'msplat'”**  
  Run: `pip install msplat` (and use Python 3.12+).

- **“colmap: command not found”**  
  Run: `brew install colmap`.

- **App: “Upload failed” / connection error**  
  Same Wi‑Fi, correct Server URL, backend running, and (if needed) that `Info.plist` allows HTTP (see project’s `RoomScanTest/Info.plist`).

- **Backend: “Training failed” / Python traceback**  
  Check the terminal where `app.py` is running. Typical causes: too few images (aim for 20+), or COLMAP/msplat error (run `python3 check_setup.py` again).
