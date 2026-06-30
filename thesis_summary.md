# Thesis Summary: Augmented Reality-Based Interior Design
## A Mobile Application for Parametric Room Scanning and Interactive 3D Scene Reconstruction
**Author:** Ielciu Mara | **Supervisor:** Prof. Dr. Darabant Sergiu Adrian | **University:** Babes-Bolyai Cluj-Napoca, 2026

---

## Overview

This thesis builds an iOS application that lets a user scan a room once, save it as a structured 3D model (a "digital twin"), and then redesign its furniture from anywhere — without needing to return to the physical space. It integrates Apple's RoomPlan and Object Capture APIs, a custom Metal-based 3D Gaussian Splatting renderer, and a SHARP single-image neural reconstruction client.

---

## Chapter 1 — Introduction

### 1.1 Motivation and Objectives

**Summary:** The thesis identifies two problems with existing interior design tools. Traditional tools (2D floor plans, catalogues) strip away perceptual properties like occlusion and lighting. Consumer AR apps (IKEA Place, Wayfair) fix this partially but treat the room as a transient floor plane — there is no persistent room model and the user must be physically present for every edit. The proposed solution is to treat the room scan itself as the primary artifact: a "digital twin" captured once and edited indefinitely.

**Why it matters:** Without a persistent model, every design iteration requires the user to be on-site holding their phone — this is a tool for a single shopping moment, not for the extended iterative redesign process that real interior decisions involve.

**Five objectives are set:**
1. **Room-scale semantic capture** — use RoomPlan to produce typed structural elements (walls, floors, ceilings, doors, windows) plus classified furniture instances with metric positions.
2. **Persistent virtual staging** — a non-AR 3D editor that saves state across sessions, so edits survive app restarts and can be done remotely.
3. **Object-scale asset authoring** — use Object Capture to scan physical furniture and produce USDZ models, eliminating dependency on external photogrammetry software.
4. **Alternative scene representation** — import and view 3D Gaussian Splatting `.ply` files via a custom Metal renderer, enabling comparison with mesh-based staging.
5. **DCC export** — export the staged room as a ZIP archive (gITF scene + USDZ furniture + JSON manifests + Blender Python script) so the design can be refined in desktop tools.

### 1.2 Contributions and Scope

- A **unified scan-to-edit pipeline** on iOS: RoomPlan → serialised room model → RealityKit editor → furniture replacement with session persistence.
- **Theoretical framing** of Apple's Object Capture within the classical photogrammetric literature (SfM → MVS → Poisson surface reconstruction).
- A **Metal-based Gaussian splat renderer** that loads binary PLY files and renders interactively via CPU-side depth sorting and alpha blending.
- A **virtual decor extension** — wall art, carpet, and dynamic lighting — within the same persistence path as furniture.
- A **Blender-oriented export service** packaging the room into a shareable ZIP.
- A **reference SwiftUI/MVVM architecture** where room metadata is kept lightweight while heavy scan payloads live on disk.

**Scope limitations:** No novel neural architectures for room understanding (RoomPlan's models are Apple proprietary); 3DGS training is off-device; full LiDAR quality requires iPhone 12 Pro or later.

### 1.3 Thesis Structure

| Chapter | Content |
|---------|---------|
| 2 | Related work: commercial AR apps, semantic datasets, SLAM, usability studies, NeRF → 3DGS |
| 3 | Theory: photogrammetry pipeline, depth fusion, Apple's Object Capture and RoomPlan APIs |
| 4 | Theory: 3D Gaussian Splatting, differentiable rendering, SHARP single-image inference |
| 5 | Requirements and system specification |
| 6 | Architecture, implementation, and evaluation |
| 7 | Conclusions, limitations, future work |

---

## Chapter 2 — Related Work in Mobile Room Capture and 3D Scene Representation

### 2.1 Commercial AR Interior Design Applications

**Summary:** Apps like IKEA Place, Wayfair, Houzz, and Amazon use ARKit plane detection to anchor virtual furniture on a detected floor. They reduce purchase uncertainty but have no room model — no walls, openings, or existing furniture are captured, and nothing persists after the session ends. Each new placement starts from scratch.

**Research gap they leave:** No single consumer tool captures a structured, metric, persistent room model; supports off-site editing; and authors 3D assets on device.

### 2.2 Indoor Scene Understanding and Semantic Datasets

**Key terms:**
- **ScanNet** — a large RGB-D dataset with per-instance semantic labels (walls, chairs, tables, etc.), demonstrating that semantic 3D structure is achievable from commodity depth cameras.
- **Matterport3D** — extends similar semantics to multi-room, building-scale scenes with 40-category labels.
- **RoomPlan API** — Apple's on-device consumer subset of this capability: produces a 'CapturedRoom' with typed surfaces and classified object instances in 1–3 minutes during an interactive scan.

**Importance:** These datasets proved that joint geometry + semantics is more useful for downstream design tasks than raw geometry alone. RoomPlan brings this to consumer iPhones.

### 2.3 Dense SLAM and Volumetric Reconstruction

**Key terms:**
- **SLAM (Simultaneous Localisation and Mapping)** — a family of algorithms that build a 3D map of the environment while simultaneously tracking the camera's position within it.
- **KinectFusion** — pioneering real-time SLAM that fused depth readings into a TSDF volumetric grid.
- **ElasticFusion / BundleFusion** — extensions that scaled SLAM to full-room sized volumes; used to capture large datasets like ScanNet.
- **Visual-Inertial Odometry (VIO)** — ARKit's technique: combining camera images with inertial sensor (IMU) data to track motion without external markers. More robust than pure visual tracking.
- **ORB-SLAM3** — a state-of-the-art research system demonstrating the maturity of feature-based VIO.

**Relation to this thesis:** RoomPlan builds on ARKit's VIO tracking but goes further — instead of raw geometry it outputs a structured room description with named walls, doors, windows, and labelled furniture instances.

### 2.4 Mobile AR Usability Evaluation

**Summary:** Kandil et al. [KAJD21] conducted standardised usability studies of commercial AR interior design apps. Weakest dimensions were *manipulation precision* (users struggled to position virtual objects accurately) and *environmental awareness* (transient plane anchoring weakened spatial understanding). Users also explicitly flagged the absence of saved sessions as a missing feature.

**How this thesis responds:** The non-AR 3D editor grounded to a captured metric model directly targets both failure modes. The requirement for persistence (R-5) is directly motivated by this study.

### 2.5 Novel View Synthesis: From NeRF to 3D Gaussian Splatting

**Key terms:**
- **Novel View Synthesis** — the task of generating a photorealistic image of a scene from a new camera angle, given only existing photographs.
- **Neural Radiance Fields (NeRF)** — a neural network trained on photos to predict radiance (colour + density) at any 3D point, enabling new-view rendering. Quality is high but training takes hours and rendering is too slow for interactive use.
- **3D Gaussian Splatting (3DGS)** — replaces the neural field with an explicit cloud of small 3D "blobs" (Gaussians), each with position, shape, colour, and opacity. Gaussians are projected onto the screen and blended in depth order. Achieves real-time frame rates at NeRF-comparable quality.
- **COLMAP** — a standard photogrammetry tool used to initialise 3DGS with a sparse point cloud from structure-from-motion.

**Role in this thesis:** 3DGS training runs on a desktop machine; the resulting `.ply` file is imported into a Metal-based viewer on the phone. PocketGS (GFYW26) shows on-device training is approaching feasibility but is not yet practical; the viewer is designed to be compatible when it matures.

### 2.6 Summary and Research Gap

No surveyed consumer or research toolchain delivers all of the following together on a single mobile platform:
1. Metric typed room model
2. Persistent off-site editing
3. On-device asset authoring
4. Gaussian splat viewing
5. DCC export
6. Usability-informed interaction model (non-AR persistence-first editor)

Closing this gap is the thesis's claimed contribution.

---

## Chapter 3 — Photogrammetry, Depth Fusion, and Apple Capture APIs

### 3.1 Motivation

**Summary:** Users redesign interiors more confidently when they see alternatives in context. Traditional representations (2D plans, catalogue photos) omit depth and occlusion. AR composites virtual furniture into a live video, but ties the experience to physical presence. If the room is captured as a structured 3D model first, the user can reopen and edit it at any time.

### 3.2 Photogrammetry and the Classical Reconstruction Pipeline

#### 3.2.1 Definition and Triangulation

**Photogrammetry** — the discipline of extracting metric (real-world measurement) information from photographs.

**Triangulation** — the core geometric operation: corresponding points seen in two or more calibrated camera images determine a 3D point by intersecting the rays from each camera through those image points.

**Bundle Adjustment** — a global optimisation that jointly refines all camera poses (positions + orientations) and 3D point positions by minimising **reprojection error**: the sum of squared distances between where each 3D point is predicted to appear in each image versus where it was actually detected.

**Formula (Bundle Adjustment):**
```
minimise Σ_{i,j} ‖x_{ij} − π(P_j, X_i)‖²
```
- `x_{ij}` = observed 2D image point (where the feature was detected)
- `π(P_j, X_i)` = predicted 2D location of 3D point `X_i` projected through camera `P_j`
- Minimising this drives camera poses and 3D points to be geometrically consistent across all images

#### 3.2.2 From Features to Textured Mesh — the 5-Stage Pipeline

| Stage | What happens | Key technique |
|-------|-------------|---------------|
| 1. Feature detection and matching | Distinctive keypoints extracted and matched across images | SIFT (Scale-Invariant Feature Transform) |
| 2. Structure from Motion (SfM) | Camera intrinsics (focal length etc.) and extrinsics (position, orientation) estimated together with a sparse 3D point cloud | Bundle adjustment |
| 3. Multi-View Stereo (MVS) | Dense correspondence estimation across views → dense point cloud or per-view depth maps | |
| 4. Surface reconstruction | Dense samples converted to a watertight mesh | Poisson surface reconstruction |
| 5. Texture mapping | Mesh is parameterised; colours blended from source images onto surface | |

**Poisson Surface Reconstruction** — solves for an "indicator function" (inside/outside the surface) whose gradient aligns with the surface normals estimated from the dense point cloud, then extracts the surface as a mesh (using Marching Cubes).

This end-to-end path is what Apple's **Object Capture** implements on-device.

### 3.3 Depth Fusion and TSDF-Based Scene Meshing

**TSDF (Truncated Signed Distance Function)** — a volumetric representation for room-scale reconstruction. The 3D volume is divided into a grid of **voxels**. Each voxel stores:
- A signed distance value: positive = outside surface, negative = inside, zero = on the surface
- A weight (confidence)

Each new depth frame from LiDAR updates voxels along viewing rays. Over time, noise averages out and a coherent surface emerges. The mesh shown in AR debugging views is an **isosurface** (the zero-level set) of this field.

**Why TSDF works for rooms but not pure photogrammetry:** TSDF is driven by measured depth, so textureless walls (which fool photogrammetric feature matching) still contribute valid depth readings.

**Semantic interpretation is added on top by RoomPlan** — deciding which planar patch is a "wall" and which blob is a "sofa" is not solved by the TSDF alone; RoomPlan uses learning-based detection and classification.

### 3.4 Image-Only versus Depth-Assisted Reconstruction

| Aspect | Object Capture | RoomPlan |
|--------|---------------|----------|
| Primary sensing | Dense RGB coverage | LiDAR depth + RGB + IMU |
| Dominant geometry cue | Photo-consistency (MVS) | TSDF fusion + plane fitting |
| Typical output | Textured triangle mesh (USDZ) | Parametric walls, openings, objects |
| Semantics | Optional masking | Built-in categories (chair, table…) |

### 3.5 On-Device Capture Pipeline

**Object Capture pipeline (left column in thesis):**
Multi-view RGB images → Feature detection & matching → SfM → MVS → Surface reconstruction (Poisson) → USDZ mesh

**RoomPlan pipeline (right column):**
LiDAR + RGB + IMU → VIO tracking → TSDF depth fusion → Plane fitting & semantics → Parametric fitting → CapturedRoom

Both pipelines feed the **RealityKit Editor** in the application: Object Capture produces furniture USDZ assets; RoomPlan provides the room substrate.

**CapturedRoom** — Apple's data structure output by RoomPlan. Conforms to `Codable` (Swift's serialisation protocol), so applications can persist scans as JSON files. Contains typed surfaces (walls, floors, ceilings) and object instances with `category`, `dimensions`, and `transform`.

### 3.6 Limitations

- Photogrammetry fails on glass, mirrors, and uniform surfaces.
- RoomPlan can miss small objects, merge adjacent pieces, or mislabel categories.
- Bounding boxes are not CAD precision.

These motivate optional Blender export for refinement.

---

## Chapter 4 — 3D Gaussian Splatting

**Context:** Neural Radiance Fields (NeRF) showed a scene can be encoded as a continuous volumetric function learned by a neural network, enabling high-quality novel-view synthesis. However, training takes hours and rendering is far too slow for interactive use. 3DGS (Kerbl et al., 2023) replaces the neural field with explicit, rasterisable Gaussians.

### 4.1 Representation: 3D Gaussian Primitives

Each Gaussian primitive stores:
- **Mean μ ∈ ℝ³** — the 3D centre (position) of the blob
- **Covariance Σ** — describes the blob's elongation (shape) and orientation
- **Opacity α** — how transparent the blob is
- **Colour** — either a fixed RGB or view-dependent colour via spherical harmonics

**How Σ is built** (from Kerbl et al.):
```
Σ = R S S^T R^T
```
- `R` = rotation matrix (derived from a unit quaternion `q`) — controls orientation
- `S = diag(s)` = diagonal scale matrix with positive entries — controls elongation
- This factorisation ensures Σ is always a valid (positive semi-definite) covariance matrix

**Spatial falloff formula:**
```
G(x) = exp( −½ (x − μ)^T Σ^{−1} (x − μ) )
```
- `x` = a point in world space
- Large G(x) means x is near the centre of the primitive along its principal axes
- This is the standard 3D Gaussian function; it defines how strongly a Gaussian influences nearby points

**Intuition:** Think of each Gaussian as a soft, oriented "blob" of radiance in space. Many overlapping blobs approximate geometry and appearance without explicit triangle connectivity.

### 4.2 Projection, Rasterisation, and Real-Time Rendering

To render, each Gaussian is projected from 3D space onto the 2D image plane in four steps:

1. **Project mean μ** using camera extrinsic and intrinsic matrices
2. **Project covariance** to a 2×2 image-space covariance Σ' using the **Jacobian J** of the perspective mapping at μ — producing an oriented elliptical footprint
3. **Sort** primitives by depth (back to front)
4. **Rasterise** with alpha blending, accumulating colour along each pixel's ray

**Alpha compositing formula (the "over" operator):**
```
c_out = α · c_G + (1 − α) · c_in
```
- `c_G` = the Gaussian's colour (possibly view-dependent)
- `α` = opacity after evaluating the projected footprint
- `c_in` = colour accumulated from Gaussians farther from the camera
- This is applied front-to-back along the sorted list of Gaussians covering each pixel

**Why this achieves real-time rendering:** The formulation maps naturally to GPU rasterisation — Gaussians become instanced quads, the vertex shader projects the covariance, and the fragment shader evaluates the Gaussian falloff.

### 4.3 Differentiable Rendering and Optimisation

To *train* (fit) Gaussians to photographs, the renderer must be **differentiable**. A photometric loss L (typically L2 or a combination with structural terms) compares rendered and ground-truth images. Gradients ∂L/∂c_out propagate back through:

1. Alpha compositing → adjusts per-Gaussian colour and opacity
2. Rasterisation → pixels influenced by a Gaussian receive scattered gradients
3. Projection → errors on the image plane differentiate through the Jacobian J, updating μ (position), s (scale), q (rotation), and α (opacity)

**Training loop:**
1. Initialise Gaussians from sparse SfM point cloud
2. Render from a sampled training viewpoint
3. Compute L between rendered and reference image
4. Backpropagate to update all Gaussian parameters
5. Apply densification/pruning (split large Gaussians, clone under-reconstructed regions, cull near-transparent ones)
6. Repeat until convergence

This loop requires hundreds of thousands of gradient-descent iterations on a GPU — practical for offline training but not for real-time mobile use.

### 4.4 Limitations of Classical 3DGS for Mobile and Real-Time Capture

| Limitation | Detail |
|-----------|--------|
| Multi-view requirement | Needs 50–200+ carefully distributed photographs |
| Dependency on SfM | COLMAP must run before training (minutes to hours) |
| Per-scene optimisation | Model trained on one room cannot reconstruct another without retraining |
| Adaptive densification overhead | Splitting/cloning/pruning Gaussians during training is hard to port to mobile |
| Relative scale | Without metric depth, absolute scale is unknown |

**Conclusion:** Classical 3DGS training is impractical for real-time, user-initiated mobile capture. This thesis therefore: uses pre-trained `.ply` files for viewing; keeps USDZ meshes as the editing medium; and uses SHARP as a feedforward alternative.

### 4.5 Meshes versus Gaussians: Editability and Role in the Application

| Criterion | Mesh (USDZ) | 3DGS (.ply) |
|-----------|------------|------------|
| Geometry | Explicit triangles | Cloud of Gaussians |
| Rendering | RealityKit / Metal mesh | Splatting |
| RoomPlan alignment | Scale-to-bounds, grounding | Manual alignment if needed |
| Editing in app | Yes (replace, transform) | View / compare only |

**Design decision:** USDZ for furniture authoring and replacement; `.ply` splats for visualisation and comparison with mesh representations.

### 4.6 SHARP: Feedforward Single-Image 3D Gaussian Splatting

**SHARP (Sharp Monocular View Synthesis)** — a model developed at Apple, presented at ICLR 2026. Given a *single* RGB photograph, it predicts the full set of 3D Gaussian parameters for the depicted scene in one forward pass through a neural network — no iterative optimisation, no multi-view input, no SfM preprocessing.

| Aspect | Classical 3DGS | SHARP |
|--------|---------------|-------|
| Input | Multi-view images + poses | Single image |
| Pose estimation | COLMAP SfM (offline) | Not required |
| Inference mode | Per-scene optimisation | Single forward pass |
| Inference time | Minutes to hours | <1s (GPU) / ~10s (Apple Silicon) |
| Gaussian count | Adaptive (10⁴–10⁶) | Fixed ~1.2M |
| Depth source | SfM (relative scale) | Depth Pro (metric) |
| Colour model | Spherical harmonics | Plain RGB |
| Generalisation | Per-scene only | Zero-shot |
| Mobile suitability | Impractical on-device | Via local server call |

**How SHARP works in this application:**
- A Flask server on a Mac on the local network loads SHARP weights once at startup
- The iOS client photographs a scene and POSTs a JPEG to the server
- Server runs SHARP inference, prunes output from 1.2M Gaussians to 300k (top opacity scores) — reducing 66MB to ~18MB
- The pruned `.ply` is returned and opened in the same Metal orbit viewer used for offline-trained splats

**Key challenge solved:** The default iOS URLSession has a 60-second timeout, insufficient when the server must compile Metal shaders on first run. A custom URLSession with 360-second timeout resolves this.

**Three properties relevant to this application:**
1. Real-time novel-view rendering via standard 3DGS rasterisation
2. Absolute metric scale (enabling physically meaningful AR sensor compatibility)
3. Zero-shot generalisation across indoor and outdoor scenes

---

## Chapter 5 — Requirements and System Specification

### 5.1 Target Users and Interaction Scenarios

**Primary user:** A homeowner or office tenant who owns a compatible iPhone or iPad and wants to preview furniture changes without purchasing them.

**Core use cases (UC-1 through UC-9):**
- UC-1: Capture a room with RoomPlan and save it
- UC-2: Open the saved room in the 3D editor
- UC-3: Select a detected furniture instance and assign a replacement USDZ model
- UC-4: Adjust position, orientation, and scale with gestures
- UC-5: Leave the app and return with edits intact
- UC-6: Capture a standalone object with Object Capture and add it to the furniture library
- UC-7: Import a 3DGS `.ply` and view it alongside or instead of a mesh
- UC-8: Capture a single photograph and receive an interactive 3DGS scene from SHARP within 2–10 seconds
- UC-9: Export the staged room as a Blender ZIP

### 5.2 Functional Requirements

| Req. | Description |
|------|-------------|
| R-1 | Room capture: run RoomPlan and produce a CapturedRoom |
| R-2 | Persistence: serialise CapturedRoom to JSON; reload on demand |
| R-3 | Editor scene: build a RealityKit 3D scene without requiring a live AR session |
| R-4 | Furniture replacement: bind USDZ to detected object, scale and position it |
| R-5 | Manipulation: translate, rotate, scale via gestures |
| R-6 | Object Capture: guided object-scanning flow producing USDZ |
| R-7 | Gaussian splat viewing: parse `.ply`, render interactively at 60fps |
| R-8 | Room deletion: delete room with confirmation; remove all associated artefacts |
| R-9 | SHARP inference: send JPEG, receive `.ply`, open in splat viewer |
| R-10 | Server reachability: health-check ping before inference; display reachability status |
| R-11 | Blender export: produce ZIP with gITF scene, USDZ furniture, JSON manifests, Python helper |

### 5.3 Non-Functional Requirements

| Req. | Description |
|------|-------------|
| N-1 | Performance: editing remains interactive at comfortable frame rates |
| N-2 | Privacy: no scan data uploaded to third-party cloud for Apple API paths |
| N-3 | Usability: guidance during RoomPlan and Object Capture sessions |
| N-4 | Maintainability: MVVM separation of models, services, and views |
| N-5 | Portability: targets minimum iOS version for RoomPlan + Object Capture; graceful LiDAR degradation |
| N-6 | Network resilience: dedicated URLSession with 360s request / 600s resource timeout for SHARP |
| N-7 | Responsiveness: progress indicator for operations > 0.5s |
| N-8 | Error handling: crash-free on corrupt PLY, failed SHARP response, network timeout, cancelled Object Capture, delete-while-open |

### 5.4 System Specification

- **Language/UI:** Swift 6, SwiftUI, Combine
- **Graphics/AR:** RealityKit (room editor), ARKit + RoomPlan (capture), Metal via MTKView (Gaussian splat renderer)
- **Data formats:** CapturedRoom encoded as JSON via Codable; USDZ for meshes; PLY for splats
- **Storage:** Room scan files under `Documents/RoomScans/`, one file per room identifier

### 5.5–5.6 Constraints and Risk Analysis

Key risks and mitigations:

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| SHARP server unavailable | Medium | Medium | Health-check ping; graceful error card; other features independent |
| SHARP first-run timeout (~2min) | High | Medium | Custom URLSession 360s timeout; UI warning overlay |
| Large `.ply` rendering lag | High | High | Server-side pruning to ≤300k Gaussians |
| RoomPlan incomplete on non-LiDAR | Medium | High | LiDAR capability gate; non-LiDAR devices use SHARP + Object Capture only |
| Object Capture insufficient coverage | Medium | Medium | Minimum image count enforced |
| Accidental room deletion | Low | High | Confirmation alert with destructive label |

---

## Chapter 6 — System Architecture, Implementation and Evaluation

### 6.1 Architectural Overview

The application is structured into four explicit layers:

1. **SwiftUI Views** — declarative UI: AppSplashView, UserSelectionView, RoomScanView, RoomDesignerView, FurnitureLibraryView, SHARPCaptureView
2. **Observable Managers** — ObservableObject classes holding domain state: UserManager, AuthenticationManager, RoomManager, ProjectManager, FurnitureCatalogManager, ScannedFurnitureManager, HistoryManager
3. **Services and Renderers** — stateless utilities: SHARPService (HTTP client), GaussianSplatRenderer (Metal GPU pipeline, instantiated per view), SmartSuggestionsService, RoomColorCaptureService
4. **Apple Frameworks and Storage** — RoomPlan, Object Capture, RealityKit, Metal, Google Sign-In SDK; persistent artefacts in Documents directory

### 6.2 Design Patterns

| Pattern | Where used | Why |
|---------|-----------|-----|
| MVVM (Model-View-ViewModel) | Entire app | Keeps views as pure declarative SwiftUI; domain state in ObservableObject managers testable independently of UI |
| Observer | @Published properties on managers | SwiftUI subscribes views automatically; no polling needed |
| Repository | RoomManager | Encapsulates all CRUD for 'Room' behind a stable interface; hides whether data comes from cache, UserDefaults, or disk |
| Facade | SHARPService | Hides custom URLSession configuration, timeout, health-check, and response parsing behind two call sites |
| Singleton | SmartSuggestionsService and similar stateless helpers | Shared as environment objects |
| Strategy | GaussianSplatView | Multi-frame 3DGS and single-image SHARP are interchangeable strategies both producing a `.ply` consumed by the same viewer |

### 6.3 Validation and Security

**Input validation:**
- Room names checked for emptiness and duplicates
- SHARP server URL validated as parseable URL with http/https scheme
- PLY files validated for magic bytes, vertex-count headers, and expected property names before opening
- Object Capture enforces minimum image count before reconstruction

**Security:**
- User passwords salted and hashed with SecRandomCopyBytes; stored in SwiftData SQLite
- Authentication tokens stored in iOS system Keychain (excluded from unencrypted backups)
- Room scan data and USDZ assets in sandboxed Documents/ — inaccessible to other apps
- SHARP inference travels only to user-configured LAN server; no third-party cloud involvement

### 6.4 Data Model and Persistence

#### 6.4.1 Room Aggregate

The `Room` Swift struct (Codable) holds:
- Identity (id, userId), timestamps
- List of `FurnitureReplacement` records
- Optional `RoomMaterials` (wall/floor colours)
- Optional `projectId`

It does **not** embed the full `CapturedRoom` — heavy scan data is stored separately.

#### 6.4.2 CapturedRoom Storage

Because each CapturedRoom JSON can reach several megabytes, it is stored separately:
- **Directory:** `Documents/users/{userId}/RoomScans/`
- **File naming:** `{roomUUID}.json` — renames don't collide with scan blobs
- **In-memory cache:** Static dictionary mapping room ID → loaded CapturedRoom instance; avoids repeated disk I/O
- **API:** `setCapturedRoom(_:)`, `getCapturedRoom()`, check-existence helpers

#### 6.4.3 Four-Layer Persistence Architecture

| Layer | What it stores | Size | Technology |
|-------|---------------|------|-----------|
| SwiftData (SQLite) | User accounts (email, password salt/hash, Google ID) | Small | SwiftData |
| UserDefaults (JSON-encoded) | Room list metadata, project records, scanned furniture catalogue, SHARP server URL | 1–5 KB per entry | JSONEncoder + UserDefaults |
| JSON files on disk | CapturedRoom (wall geometry, object transforms, structural elements) | Several MB per room | Atomic file writes |
| In-memory cache | Currently loaded CapturedRoom instances | Session-only | Static dictionary |

**Key architectural decision:** Separating lightweight metadata (UserDefaults) from heavy scan artefacts (disk files) makes the room list load instantly regardless of how many large scans are stored.

#### 6.4.4 Furniture Replacement Records

`FurnitureReplacement` ties a RoomPlan object identifier to a USDZ resource name/path plus transform overrides. It supports three **virtual decor categories** beyond direct furniture replacement:

- **Wall art** — user selects a frame style/size and optionally provides a photo; stored as JPEG referenced by filename; RealityKit entity applies image as texture on a plane mesh anchored to the nearest detected wall
- **Carpet** — pattern, colour, and size presets plus custom dimensions; flat rectangular mesh placed on the floor plane
- **Lighting** — maps to a RealityKit point or spot light with RGB colour and luminous intensity in lumens; placed at user-chosen ceiling or wall position; affects PBR shading of other entities in the scene

All three share the same `FurnitureReplacement` persistence path, discriminated by the `originalCategory` string ("wallArt", "carpet", "lighting").

### 6.5 Data Flow: Scan to Editor

End-to-end sequence:

1. **Capture** — RoomCaptureView runs RoomPlan session until user finalises; app receives CapturedRoom
2. **Commit** — RoomManager stores Room list; `setCapturedRoom` writes scan JSON to disk
3. **Open editor** — Designer view calls `getCapturedRoom()`, builds RealityKit entities for walls, floor, openings, and for each object either a placeholder box or a resolved USDZ replacement
4. **Edit** — Gestures update entity transforms; changes write back to FurnitureReplacement; RoomManager persists
5. **Relaunch** — RoomManager.loadRooms restores catalogue; selecting a room reloads scan JSON from disk into cache and reconstructs the scene exactly as left

### 6.6 Key Modules and Views

- **MainTabBar** — primary navigation: Furniture, Rooms, Projects tabs
- **RoomScanView** — embeds RoomPlan capture experience; finalises session via `RoomCaptureSession.stop(pauseARSession: true)`
- **RoomDesignerView** — largest module; hosts RealityKit ARView in non-AR camera mode; wires gesture recognisers; coordinates furniture picking; integrates wall art, carpet, suggestions, measurements
- **ObjectScanView** — drives ObjectCaptureSession; displays guidance; runs PhotogrammetrySession; registers result with ScannedFurnitureManager
- **GaussianSplatData.swift** — parses binary or ASCII PLY layouts, normalising property names
- **GaussianSplatRenderer.swift** — uploads instances to GPU buffers; sorts by depth each frame; issues Metal draw calls approximating 2D Gaussian falloff and blending
- **SHARPCaptureView / SHARPService** — manages camera, sends JPEG, handles response, opens resulting `.ply` in GaussianSplatView

### 6.7 USDZ Alignment Heuristics

When a replacement USDZ is first bound, it must align to the RoomPlan-detected bounding volume without distorting the model. Two rules:

**1. Uniform scale:**
```
s = min(d_x^room / d_x^usdz,  d_y^room / d_y^usdz,  d_z^room / d_z^usdz)
```
- `d_x^room`, `d_y^room`, `d_z^room` = dimensions of the RoomPlan-detected bounding box
- `d_x^usdz`, `d_y^usdz`, `d_z^usdz` = dimensions of the USDZ model's axis-aligned bounding box
- Taking the **minimum** ratio ensures the model fits inside the detected bounds on every axis without exceeding any of them, while preserving aspect ratio (no distortion)

**2. Floor grounding:** After scaling, the entity's local y-origin is translated so the bottom face sits flush with the detected object's base plane.

A `customScale` field in `FurnitureReplacement` stores an additional user-applied multiplier for fine-tuning after initial alignment.

### 6.8 Metal Gaussian Splatting: Rendering Pipeline

The splat renderer implements the Kerbl et al. formulation adapted for iOS Metal. Unlike the original CUDA implementation (tile-based parallel radix-sorted rasterisation), this uses a single-pass instanced draw call with CPU-side back-to-front sort — simpler, trading parallelism for portability.

**Per-frame pipeline steps:**

1. **Orbit camera** → compute viewMatrix, projMatrix (fovY=π/3, near=0.01, far=200)
2. **Sort Gaussians** — depth = dot(viewRow2, position); sort back-to-front O(n log n) on CPU
3. **Upload sorted indices** to MTLBuffer
4. **Encode** triangle strip × 4 verts × N instances draw call

**Vertex shader (gaussianVertex):**

Computes 3D covariance:
```
Σ = MM^T,   M = R · diag(s)
```
(R from quaternion via `quatToRotMat` Metal function; s = per-Gaussian scale)

Projects to 2D screen-space covariance:
```
Σ' = TΣT^T,   T = J·W
```
where:
```
J = ( f_x/d    0      f_x·t_x/d² )
    ( 0        f_y/d  f_y·t_y/d² )
    ( 0        0      0           )
```
(J = Jacobian of perspective at Gaussian centre; f_x, f_y = focal lengths; d = depth; t_x, t_y = image-plane position)

Computes quad half-extent from the dominant eigenvalue of Σ':
```
λ_max = tr(Σ')/2 + √( (tr(Σ')/2)² − det(Σ') )
```
Quad half-extent = 3√λ_max

**Fragment shader (gaussianFragment):**

Evaluates the 2D Gaussian exponent:
```
α = σ · exp(−½ d^T Σ'^{−1} d)
```
where `d` = pixel offset from projected Gaussian centre, `σ` = stored per-Gaussian opacity, and Σ'^{−1} is the 2×2 inverse of the projected covariance.

Fragments with α < 1/255 are discarded early; remaining fragments use premultiplied-alpha blending with blend factors (1, 1−srcA).

**Depth sorting performance:** For up to 300k Gaussians (server-side pruning limit), the CPU sort takes ~10–30ms on an A-series CPU, fitting within a 60Hz frame budget.

### 6.9 On-Device versus Off-Device Processing

| Processing | On-device | Off-device |
|-----------|----------|-----------|
| RoomPlan scan interpretation | Yes | — |
| Object Capture reconstruction | Yes | — |
| USDZ display in RealityKit | Yes | — |
| 3DGS training | — | Yes (desktop workstation) |
| SHARP inference | — | Yes (user-controlled LAN Mac) |

The SHARP path is a hybrid: the device captures and sends a single image, but inference runs on the user's Mac — preserving the privacy guarantee (N-2) that no scan data goes to third-party cloud infrastructure.

### 6.10 User Interface Walkthrough

Seven-step end-to-end workflow:

1. **Start RoomPlan capture** — walk around the room; walls, openings, and furniture appear incrementally in the live preview
2. **Finalise scan** — tap Done; scan processes into a typed geometry model with every wall, window, and furniture item labelled and positioned in metric space
3. **Persist and open editor** — room saved automatically; 3D editor accessible from anywhere, with orbit/zoom/inspect from any angle
4. **Replace furniture** — tap a detected piece; select replacement from catalogue; virtual model snaps to original position/scale; gestures fine-tune; every change persists
5. **Add virtual decor** — hang wall art, place a carpet, or adjust ambient lighting, anchored to real detected surfaces
6. **Optional: view a Gaussian splat** — photograph a corner or object; within ~10s a volumetric reconstruction appears in the splat viewer
7. **Relaunch verification** — closing and reopening restores everything exactly as left

### 6.11 Testing

#### 6.11.1 Functional Tests

Manual test cases map each requirement to an observable outcome (verified by the tester):

| Req. | Test procedure |
|------|---------------|
| R-1, R-2 | Scan room; verify scan JSON saved to disk |
| R-3, R-4 | Open editor; confirm walls and at least one object mesh; bind a USDZ |
| R-5 | Transform model; kill app; reopen; transforms preserved |
| R-6 | Complete object scan; USDZ appears in furniture picker |
| R-7 | Import known-good `.ply`; orbit without artefacts at 60fps |
| R-8 | Delete room; confirm alert; verify .json removed from disk; list updated |
| R-9 | Configure server URL; capture photo; receive and display `.ply` in splat viewer |
| R-10 | Stop server; reachability indicator turns red; capture button disabled with error |
| R-11 | Trigger Blender export; verify ZIP contains room_scene.gltf, at least one .usdz, and blender_import.py |

#### 6.11.2 Unit Tests

16 automated unit tests cover deterministic, side-effect-free logic:
- Gaussian splat import validation (vertex count, coordinate-frame conversion, opacity remapping)
- Room and FurnitureReplacement encode–decode round-trips
- Uniform model scaling with edge cases (degenerate extents)
- Orphaned room-scan file cleanup (leaves active scans and unrelated file types intact)
- Cloud-based splat training REST endpoint paths and status-response parsing

#### 6.11.3 Quantitative Evaluation: Object Scan

**Setup:** 20 captures across 6 scenes; four conditions: opaque/plain background, opaque/cluttered background, transparent/plain background, transparent/cluttered background. Ground-truth dimensions measured with a ruler prior to scanning.

**Metrics:**
- **MAE (Mean Absolute Error)** over width, height, depth — measures average dimension error
- **IoU (Intersection over Union)** of bounding boxes — measures how well the reconstructed box overlaps the true box (1.0 = perfect)

**Results:**

| Overall metric | Value |
|---------------|-------|
| Number of captures | 20 |
| Mean absolute dimension error | 3.44 mm |
| Mean bounding-box IoU | 0.796 |

| Condition | MAE (mm) | IoU |
|-----------|----------|-----|
| Plain background | 1.97 | 0.881 |
| Cluttered background | 4.92 | 0.710 |
| Opaque objects | 2.23 | 0.819 |
| Transparent objects | 5.51 | 0.741 |

**Interpretation:** Cluttered backgrounds and transparent materials each increase error by approximately 2.5× relative to baseline. Transparent surfaces cause contour ambiguity and unstable silhouettes at object boundaries; clutter provides competing background texture that confuses feature matching and depth estimation.

#### 6.11.4 Quantitative Evaluation: Room Scan

**Setup:** 28 captures across five room types (bedroom, living room, office, kitchen, bathroom); ground-truth room dimensions measured with a tape measure.

**Results:**

| Metric | Value |
|--------|-------|
| Rooms evaluated | 28 |
| Mean absolute length error | 1.64 cm |
| Mean absolute width error | 1.23 cm |
| Mean absolute height error | 0.87 cm |
| Combined mean dimension error | 1.25 cm |
| Maximum observed error | 3.10 cm |

**Window detection by visibility condition:**

| Condition | Trials | Detection success | Missed |
|-----------|--------|------------------|--------|
| Clear view | 17 | 100% | 0 |
| Partial drape coverage | 6 | 83% | 1 |
| Curtains closed | 5 | 60% | 2 |

**Key observations:**
1. Room dimension fidelity is stable and high — mean combined error of 1.25 cm is well within usable range for furniture replacement (furniture bounding boxes need only centimetre-level accuracy to be practically useful).
2. Height error (0.87 cm) is consistently lower than planar dimensions because ceiling and floor surfaces provide strong parallel-plane constraints for the depth fusion algorithm.
3. Window detection degrades gracefully with occlusion: even with fully closed curtains (60% detection), the model uses structural geometry cues — the model doesn't solely rely on visual window appearance.

#### 6.11.5 Qualitative Reconstruction Comparison: SHARP vs. 3DGS

**Setup:** Same living room scene reconstructed by (a) SHARP from a single photograph and (b) COLMAP+3DGS trained on 23 frames captured from the app.

**SHARP result:** Near-photographic quality within the field of view of the single input frame (sofa, wall painting, ceiling, floor rendered with high fidelity and natural lighting). The black region surrounding the scene marks the limit of coverage — SHARP cannot infer geometry beyond what the single image observed.

**3DGS result:** Covers a wider field of view (trained on 23 frames). Central scene elements are clearly reconstructed and spatially consistent. However, exhibits characteristic "Gaussian floater" artefacts at image boundaries — blurred, semi-transparent colour streaks that arise where training data is insufficient to constrain Gaussian geometry.

**Conclusion:** SHARP and 3DGS are complementary:
- **SHARP** → immediate (~10s), photorealistic within a single frame's field of view; suitable for per-frame visualisation during scanning
- **3DGS** → spatially complete coverage after a longer capture and training pipeline; suitable for free-viewpoint navigation and persistent scene storage

#### 6.11.6 3DGS Training Time: Frame Count and Capture Pattern

**Results (same scene and hardware):**

| Input frames | Room traversal | Object orbit |
|-------------|---------------|-------------|
| 20 | 20 min 17 s | 26 min 23 s |
| 30 | 36 min 50 s | 41 min 57 s |
| 40 | 42 min 44 s | 47 min 51 s |
| 50 | 49 min 00 s | 54 min 09 s |

**Observations:**
- Training time scales super-linearly at low frame counts and flattens above 40 frames (diminishing coverage returns)
- The jump from 20→30 frames (+16 min 33s) is disproportionately large relative to 40→50 frames (+6 min 16s), consistent with the densification phase requiring more iterations when the initial sparse cloud is thin
- Object-orbit captures consistently require ~5–6 minutes more than room-traversal at every frame count — orbital captures concentrate views around a small volume, producing a denser initial point cloud that increases the Gaussian densification and pruning cost

**Protocol implication:** The 20-frame room-traversal configuration was used as the representative baseline for comparative evaluations. 40 frames were reserved for confirmatory final-pass runs.

---

## Chapter 7 — Conclusions

### 7.1 Summary of Results

The application demonstrates a coherent pipeline:
**RoomPlan → serialised scan → RealityKit editor → USDZ replacements with gestures → persistence across sessions**

Object Capture extends asset authoring; the Metal splat renderer implements R-7; the SHARP integration closes the loop between on-device photography and Gaussian-field reconstruction via a local-network inference server, without third-party cloud dependency.

All requirements R-1 through R-11 and non-functional goals N-1 through N-8 are addressed.

### 7.2 Limitations

| Limitation | Detail |
|-----------|--------|
| Accuracy ceiling | Bounded by RoomPlan detection quality and photogrammetry assumptions in Object Capture |
| No closed-loop feedback | Splats and parametric room semantics are not integrated (splats can't inform room geometry and vice versa) |
| 3DGS training is external | Real-time splat training on device is research-grade; not available to end users |
| No formal usability study | The app's UX was not formally evaluated; Kandil et al. provide methodology for a future study |

### 7.3 Future Work

- **Formal user evaluation** using standardised questionnaires from Kandil et al. [KAJD21]
- **Tighter COLMAP/3DGS integration** — export scan images with ARKit poses directly into external training pipelines
- **Level-of-detail rendering** for large splat clouds on mobile
- **Semantic furniture suggestions** informed by procedural layout systems (Kán et al. [KKRLR21])
- **On-device 3DGS training** — architecturally prepared; depends on maturation of on-device training (PocketGS and similar)

**Thesis conclusion:** Merging API-level room semantics with an editable mesh workflow yields a practical middle ground between live AR stickers and professional BIM tools, suitable for the extended, iterative redesign process that conventional AR-only solutions cannot support.

---

## Glossary of Technical Terms

| Term | Definition |
|------|-----------|
| **ARKit** | Apple's augmented reality framework for iOS/iPadOS; tracks device position and detects surfaces using visual and inertial sensors |
| **Bundle Adjustment** | Optimisation that jointly minimises reprojection error across all camera poses and 3D scene points; the backbone of Structure from Motion |
| **CapturedRoom** | Apple's structured data model output by RoomPlan; contains typed walls, floors, ceilings, openings, and classified furniture instances with metric transforms |
| **Codable** | Swift protocol that enables automatic JSON/binary serialisation of data types; used for persisting CapturedRoom to disk |
| **COLMAP** | Open-source structure-from-motion and multi-view stereo tool; commonly used to initialise 3DGS training |
| **Covariance matrix (Σ)** | In 3DGS: a 3×3 positive semi-definite matrix describing a Gaussian's shape, elongation, and orientation in 3D space |
| **DCC (Digital Content Creation)** | Professional 3D tools such as Blender, Maya, Cinema 4D used for rendering, animation, and mesh editing |
| **Depth Pro** | Apple's monocular depth estimation model producing metric (absolute-scale) depth maps from single images; used by SHARP |
| **Digital twin** | A persistent, structured 3D representation of a physical space that can be edited and experimented with independently of the physical environment |
| **gITF** | GL Transmission Format; an open 3D scene format efficient for web and real-time applications; used for the Blender export room scene |
| **GPU (Graphics Processing Unit)** | Specialised processor for parallel graphics computation; used for rendering Gaussian splats and training 3DGS |
| **IMU (Inertial Measurement Unit)** | Hardware sensor measuring acceleration and angular velocity; combined with camera data in VIO for robust tracking |
| **IoU (Intersection over Union)** | Metric for bounding box accuracy: area of overlap divided by area of union; ranges from 0 (no overlap) to 1 (perfect match) |
| **Jacobian (J)** | Matrix of partial derivatives of a function; used in 3DGS to project the 3D Gaussian covariance onto the 2D image plane |
| **LiDAR** | Light Detection and Ranging; sensor that measures distances by emitting laser pulses and measuring return time; available on iPhone 12 Pro and later |
| **MAE (Mean Absolute Error)** | Average of absolute differences between predicted and ground-truth values; used to measure dimension accuracy in this thesis |
| **Metal** | Apple's low-level GPU graphics and compute API for iOS/macOS; used for the custom Gaussian splat renderer |
| **MTKView** | MetalKit view class that provides a Metal-compatible display surface; used to bridge the Gaussian splat renderer into SwiftUI |
| **MVVM** | Model-View-ViewModel; architectural pattern separating data/logic (model + viewmodel) from UI (view) |
| **MVS (Multi-View Stereo)** | Algorithm family that estimates dense 3D geometry by finding pixel correspondences across many calibrated images |
| **NeRF (Neural Radiance Field)** | Neural network trained on photographs to predict colour and density at any 3D point, enabling new-view rendering |
| **Novel view synthesis** | Generating a photorealistic image of a scene from a camera position/angle not in the original set of photographs |
| **Object Capture** | Apple's on-device photogrammetric pipeline; takes multi-view photos of an object and produces a USDZ mesh |
| **Observable / ObservableObject** | Swift/SwiftUI mechanism for reactive data binding; views automatically re-render when observed properties change |
| **Photogrammetry** | Discipline of extracting metric 3D measurements and models from photographs |
| **PLY (Polygon File Format)** | Simple binary or ASCII format for storing 3D point clouds and meshes; the standard interchange format for 3DGS Gaussian clouds |
| **Poisson Surface Reconstruction** | Algorithm that converts a dense oriented point cloud into a watertight triangle mesh by solving for an indicator function |
| **PBR (Physically Based Rendering)** | Rendering approach that simulates real-world light behaviour for more photorealistic results; used by RealityKit |
| **RealityKit** | Apple's 3D rendering and simulation framework; used for the room editor, furniture placement, and AR preview |
| **RoomPlan** | Apple's API that uses LiDAR, RGB, and IMU data to produce a structured 'CapturedRoom' model with typed surfaces and classified furniture |
| **SHARP (Sharp Monocular View Synthesis)** | Apple's feedforward neural network that predicts 3DGS Gaussians from a single RGB photograph in one forward pass |
| **SfM (Structure from Motion)** | Algorithm that estimates camera positions/orientations and a sparse 3D point cloud from a collection of overlapping images |
| **SLAM (Simultaneous Localisation and Mapping)** | Algorithm family that builds a map of an unknown environment while tracking the device's position within it simultaneously |
| **Spherical harmonics** | Mathematical functions used in 3DGS to represent view-dependent colour (a Gaussian can appear different colours from different directions) |
| **SwiftData** | Apple's Swift-native ORM (object-relational mapping) framework backed by SQLite; used for user account storage |
| **SwiftUI** | Apple's declarative UI framework for Swift; views are functions of state, re-rendering automatically on state change |
| **TSDF (Truncated Signed Distance Function)** | Volumetric representation that stores signed distance to the nearest surface at each voxel; used in KinectFusion-style depth fusion |
| **Triangulation** | Computing a 3D point from two or more 2D image observations by intersecting the corresponding camera rays |
| **USDZ** | Universal Scene Description (Pixar) format, ZIP-packaged; Apple's standard for 3D model interchange in RealityKit and AR Quick Look |
| **VIO (Visual-Inertial Odometry)** | Technique that combines camera images with IMU data to estimate device motion more robustly than either alone |
| **Voxel** | Volumetric pixel; a unit cell in a 3D grid; the building block of TSDF and volumetric reconstruction |
| **3DGS (3D Gaussian Splatting)** | Scene representation using a cloud of explicit 3D Gaussian primitives rendered by projecting and alpha-blending them in depth order; achieves real-time novel-view synthesis at NeRF-comparable quality |
