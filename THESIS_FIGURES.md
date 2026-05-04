# Thesis figures and screenshots

Place image files in the **`figures/`** folder next to `thesis.tex`. Supported formats: **PNG** (recommended) or **PDF**. The thesis currently references **`.png`** paths; tiny **1×1 placeholder PNGs** are committed so LaTeX compiles—**replace them** with your real figures.

**Important:** Run `pdflatex` from the **project root** (the folder that contains `thesis.tex` and `figures/`), otherwise paths like `figures/ch2_capture_branches.png` will not resolve.

## Chapter 2 — Theory I (pipelines)

| File | What to show | How to create it |
|------|----------------|------------------|
| `figures/ch2_capture_branches.png` | Two parallel flows: (left) RGB → SfM → MVS → Poisson → USDZ; (right) LiDAR/depth → TSDF → mesh + ML → `CapturedRoom`. | **Draw** in Keynote, PowerPoint, Figma, or draw.io; export PDF/PNG. Use simple boxes and arrows. Alternatively trace Apple’s public pipeline diagrams in your own words (no copying). |

**Optional extra (not in LaTeX by default):** a photo of a **RoomPlan scan in progress** on your iPhone (`figures/ch2_roomplan_live.png`) — screenshot during capture.

## Chapter 3 — Theory II (3DGS)

| File | What to show | How to create it |
|------|----------------|------------------|
| `figures/ch3_gaussian_projection.png` | 3D ellipsoid + camera + frustum, ellipse on image plane (conceptual). | Redraw from Kerbl et al. (2023) **paper figure idea**, not a direct paste — or use a simple TikZ-style sketch in any vector tool. |

**Optional:** side-by-side **mesh vs splat** of the **same object** (`figures/ch3_mesh_vs_splat.png`) — export from RealityKit/mesh viewer and from your Metal splat view.

## Chapter 4 — Requirements

| File | What to show | How to create it |
|------|----------------|------------------|
| `figures/ch4_context_diagram.png` | Actor “User” → App → artefacts (USDZ, PLY, JSON in Documents). | draw.io / OmniGraffle / PowerPoint. |

## Chapter 5 — Implementation (most screenshots go here)

| File | What to show | How to create it |
|------|----------------|------------------|
| `figures/ch5_architecture.png` | Layers: SwiftUI views → managers/services → RoomPlan / ObjectCapture / RealityKit / Metal / FileManager. | Diagram tool; align with section text. |
| `figures/ch5_ui_01_mode.png` | Mode selection or home (if applicable). | **Simulator or device:** ⌘+S in Simulator, or device screenshot. |
| `figures/ch5_ui_02_room_list.png` | List of rooms / projects. | Same. |
| `figures/ch5_ui_03_room_scan.png` | RoomPlan capture UI (walls highlighted). | Run app, start scan, screenshot. |
| `figures/ch5_ui_04_editor.png` | 3D room editor, orbit view, furniture visible. | After loading a scan. |
| `figures/ch5_ui_05_replace.png` | Furniture picker / replacement in progress. | During replace flow. |
| `figures/ch5_ui_06_persist.png` | Same room after kill + relaunch (proves persistence). | Two shots or one annotated. |
| `figures/ch5_ui_07_object_capture.png` | Object Capture guidance screen. | During object scan. |
| `figures/ch5_ui_08_gaussian_splat.png` | Gaussian splat view (if you use it). | Open PLY view. |

### Screenshot tips (iOS)

1. **Device:** Volume up + side button (or AssistiveTouch).  
2. **Simulator:** **File → Save Screen** or **⌘+S** (saves to Desktop).  
3. Crop status bar if your faculty prefers clean images; export **PNG**.  
4. Prefer **light-on-dark** or **dark UI** consistently across figures.  
5. **Resolution:** width 1200–1800 px is enough for A4 inclusion at `0.85\textwidth`.

### Naming

Keep names exactly as in `chapters/*.tex` so `\thesisfig{}{figures/...}` resolves without edits.
