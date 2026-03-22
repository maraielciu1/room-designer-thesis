# Checklist: End-to-End “Train in Cloud” on Your Mac

Use this to confirm everything works from the mobile app to the backend and back.

---

## 1. Backend (Mac)

- [ ] **Python 3.12+**  
  `python3 --version`

- [ ] **COLMAP**  
  `brew install colmap` then `colmap -h`

- [ ] **msplat**  
  `pip install msplat`

- [ ] **Flask**  
  `pip install -r requirements.txt` in `backend_3dgs/`

- [ ] **Run backend**  
  `cd backend_3dgs && python app.py`  
  (or `flask --host 0.0.0.0 --port 5001 run`)  
  You should see the Flask server listening.

---

## 2. Network (iPhone ↔ Mac)

- [ ] **Same Wi‑Fi**  
  iPhone and Mac on the same network.

- [ ] **Mac IP**  
  On Mac: System Settings → Wi‑Fi → your network → click (i) or run `ipconfig getifaddr en0`.  
  Example: `192.168.1.5`.

- [ ] **Or use ngrok**  
  `ngrok http 5001` and use the HTTPS URL (no ATS issues).

---

## 3. Mobile app

- [ ] **Server URL set**  
  After saving a scan, in the “Done” screen set **Server URL** to:
  - `http://<your-mac-ip>:5001` (e.g. `http://192.168.1.5:5001`), or  
  - Your ngrok URL (e.g. `https://xxxx.ngrok.io`).

- [ ] **Info.plist**  
  The project includes `RoomScanTest/Info.plist` with **NSAppTransportSecurity** so HTTP to your backend is allowed. Rebuild the app after adding it.

---

## 4. Full flow

1. In the app: **Scan an object** (Object Capture), finish, name it, **Save to My Furniture**.
2. On the **Done** screen: enter **Server URL** if needed, tap **Train in Cloud**.
3. App shows “Packaging images…”, “Uploading…”, “Training… X%”.
4. Backend runs COLMAP then msplat; when done, app downloads the `.ply` and attaches it to the object.
5. Open the object in **Furniture Library** or **Reconstruction Comparison** and you should see the Gaussian Splat view.

---

## If something fails

- **“Upload failed” / connection error**  
  Check Server URL (no trailing slash), same Wi‑Fi, Mac firewall (allow port 5001), and that the backend is running.

- **“Training failed” on backend**  
  Check backend terminal for the Python traceback. Typical causes: COLMAP not in PATH, msplat not installed, or too few images (aim for 20+).

- **App never gets “completed”**  
  Check backend logs; ensure GET `/jobs/<id>/status` returns `"status": "completed"` when done and GET `/jobs/<id>/result` returns the `.ply` file.
