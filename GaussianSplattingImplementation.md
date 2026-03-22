# Gaussian Splatting Pipeline in the App — Implementation Guide

This document describes what is already implemented and how you can extend the Gaussian splatting pipeline in the RoomScanTest app.

---

## 1. What Is Already Implemented

The app already has a **viewing pipeline** for 3D Gaussian Splatting:

| Step | Component | Role |
|------|-----------|------|
| **Import** | `FurnitureLibraryView` / `ReconstructionComparisonView` | User selects a `.ply` file; it is copied to `Documents/ScannedFurniture/{uuid}_splat.ply`. |
| **Parse** | `GaussianSplatData.swift` → `PLYParser.parse(url:)` | Reads binary/ASCII .ply, builds `GaussianSplatScene` (position, color, opacity, scale, rotation per Gaussian). |
| **Upload** | `GaussianSplatRenderer.loadScene(_:)` | Converts to `GaussianGPU` structs, creates `MTLBuffer`, prepares sorted indices. |
| **Render** | `GaussianSplatRenderer` + Metal shaders | Vertex shader projects 3D Gaussians to 2D; fragment shader evaluates Gaussian + alpha blend. |
| **UI** | `GaussianSplatView` (wraps `GaussianSplatMetalView`) | Displays the rendered splat in SwiftUI; orbit camera via gestures. |

**Training** is intentionally **external**: user exports images from Object Capture → trains in Colab or with the official 3DGS repo → imports the resulting `.ply` back. The in-app guide (`GaussianSplattingGuideView`) explains this flow.

So the “Gaussian splatting pipeline” in the app = **load → parse → upload → render**. You can describe this in the thesis as the implementation of the **viewing and comparison** part; training is out-of-scope on-device for now.

---

## 2. How to Improve the Current Pipeline (No Training On-Device)

- **More .ply formats**: If you use a trainer that outputs spherical harmonics (SH) or different property names, extend `PLYParser` to read them and pass SH to the fragment shader (or keep RGB-only for simplicity).
- **Large scenes**: For very large `.ply` files (e.g. 500k+ Gaussians), add **LOD**: e.g. subsample or cluster Gaussians by distance and reduce count for distant tiles to keep 60 fps.
- **Async loading**: Parse and upload the `.ply` on a background queue; show a progress indicator and only attach the splat to the model when loading is done.

These keep the pipeline as “import + render” and make it more robust and scalable.

---

## 3. How to Add On-Device Training (Advanced / Thesis “Future Work”)

To implement **training** of 3D Gaussians on the device:

1. **Inputs**
   - Reuse the same images as Object Capture (already saved during capture).
   - Camera poses: either export from ARKit (e.g. from each frame during capture) or run a minimal SfM on-device.

2. **Minimal SfM on-device**
   - Use Vision framework (`VNGenerateImageFeaturePrintRequest` or similar) for feature extraction; match across image pairs; triangulate to get a sparse point cloud and camera poses.
   - Alternatively, use ARKit’s provided poses during Object Capture if you can access them per captured image.

3. **Initialise Gaussians**
   - One 3D Gaussian per SfM point: position = point, small initial scale, opacity and color from nearest image.

4. **Training loop**
   - Implement differentiable splatting in Metal (render to texture, compute loss vs. training images, backprop to Gaussian parameters).
   - Run a small number of iterations (e.g. 500–1000), possibly at reduced resolution to fit memory and time budget.

5. **Output**
   - Write the trained parameters to the same .ply format the app already parses, then load them with the existing pipeline.

This is a substantial project (weeks of work) and fits well as “future work” or a proof-of-concept in the thesis.

---

## 4. Hybrid: Export Poses With Images

Without full on-device training, you can still improve the **external** pipeline:

- When the user exports images for Gaussian Splatting, also export **camera poses** (e.g. from ARKit or from a minimal on-device SfM).
- Save them in a format your external trainer accepts (e.g. COLMAP-style `cameras.txt` / `images.txt`).
- Then external training can skip COLMAP and use your poses, giving more consistent results and a clearer “pipeline” story in the thesis (capture + pose export + external 3DGS + import + render).

---

## 5. Summary for the Thesis

- **What you did**: Integrated a full **viewing** pipeline for 3D Gaussian Splatting: .ply import, parsing, Metal-based splatting renderer, and side-by-side comparison with Object Capture.
- **Theoretical concept**: 3D Gaussian Splatting (Kerbl et al.) — representation, projection, alpha blending, and its relation to mesh-based Object Capture.
- **Implementation**: The pipeline in the app is **load .ply → parse → upload to GPU → render**; training is external. Extending to on-device training is possible as future work and can be outlined as above.

Use this file as the implementation guide; use the thesis (TheoreticalFoundation.tex) for the theoretical and high-level description of the pipeline and options.
