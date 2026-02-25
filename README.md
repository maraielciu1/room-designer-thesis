# Room Designer

**Transform your space with AR** — an iOS app that scans rooms using LiDAR and lets you replace, rearrange, and add furniture in an interactive 3D scene.

Built with SwiftUI, RealityKit, ARKit, and RoomPlan as a thesis project.

## Features

### Room Scanning
- LiDAR-powered room scanning using Apple's **RoomPlan** framework
- Automatic detection of walls, floors, doors, windows, and furniture
- Rooms are saved locally and can be revisited at any time

### 3D Room Editor
- Scanned rooms are rendered as interactive 3D scenes with an orbit camera
- Detected furniture appears as colour-coded wireframe bounding boxes
- Select any piece of furniture (long press) to replace it with a USDZ model from the built-in catalogue or your own scanned objects

### Object Manipulation
- **Unity-style 3D gizmo** — red (X), green (Y), blue (Z) arrows for axis-constrained movement
- Drag near the object centre for free XZ-plane movement
- Pinch to scale, two-finger rotate
- Smooth **target-chase interpolation** prevents abrupt or jerky motion
- Objects are clamped to room bounds so they never fly out of the scene

### Object Capture
- Scan real-world objects using Apple's **Object Capture** API (photogrammetry)
- Reconstructed models are saved as USDZ and added to your personal furniture library
- Live shot counter with visual feedback during capture
- Scanned furniture retains real-world dimensions when placed in a room

### Furniture Library
- Browse built-in USDZ models (sofa, chairs, tables, shelves, lighting)
- View your own scanned objects alongside built-ins
- 3D thumbnail previews generated with `QLThumbnailGenerator`
- Add new furniture to a room without replacing existing pieces

### Multi-User & History
- Create and switch between user profiles
- Each user has their own rooms and replacement history
- Replacement history tracks every furniture swap with timestamps

## Architecture

The app follows the **MVVM (Model-View-ViewModel)** pattern:

```
RoomScanTest/
├── Models/
│   ├── Room.swift                  # Room data + CapturedRoom persistence
│   ├── FurnitureReplacement.swift  # Replacement data (transform, offset, scale)
│   ├── ReplacementHistory.swift    # History entries
│   ├── ScannedFurniture.swift      # User-scanned object metadata
│   └── User.swift                  # User profile
├── Views/
│   ├── LandingView.swift           # Home screen
│   ├── RoomListView.swift          # Saved rooms list
│   ├── RoomScanView.swift          # RoomPlan scanning UI
│   ├── RoomDesignerView.swift      # 3D scene editor (core)
│   ├── FurnitureLibraryView.swift  # Browse & manage furniture
│   ├── ObjectScanView.swift        # Object Capture workflow
│   ├── CreateRoomView.swift        # New room flow
│   ├── HistoryView.swift           # Replacement history
│   └── UserSelectionView.swift     # User switcher
├── Services/
│   ├── RoomManager.swift           # Room CRUD + persistence
│   ├── FurnitureCatalogManager.swift # Model loading & scaling
│   ├── ScannedFurnitureManager.swift # Scanned objects lifecycle
│   ├── HistoryManager.swift        # History tracking
│   └── UserManager.swift           # User management
└── RoomScanTestApp.swift           # App entry point
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| 3D Rendering | RealityKit (`ARView`, `ModelEntity`) |
| Room Scanning | RoomPlan (`RoomCaptureSession`, `CapturedRoom`) |
| World Tracking | ARKit (`ARWorldTrackingConfiguration`) |
| Object Scanning | Object Capture (`ObjectCaptureSession`, `PhotogrammetrySession`) |
| 3D Models | USDZ / USDC format |
| Thumbnails | QuickLook (`QLThumbnailGenerator`) |
| Concurrency | Swift structured concurrency (`async/await`, `@MainActor`) |
| Data | `UserDefaults` (metadata) + file system (3D data) |

## Requirements

- **iOS 17.0+**
- **iPhone or iPad with LiDAR** (iPhone 12 Pro and later, iPad Pro 2020 and later)
- **Xcode 15+**
- Object Capture requires **A14 Bionic chip or later** with **4 GB+ RAM**

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/maraielciu1/room-designer-thesis.git
   ```
2. Open `RoomScanTest.xcodeproj` in Xcode
3. Select your physical device as the build target (LiDAR required — Simulator won't work)
4. Build and run

## Usage

1. **Create a profile** on the user selection screen
2. Tap **My Rooms** → **+** to scan a new room — walk slowly around the space
3. After scanning, the room opens in the **3D editor** with detected furniture highlighted
4. **Long press** a wireframe box to select it, then pick a replacement from the catalogue
5. Use the **gizmo arrows** to position furniture precisely, pinch to scale, two-finger rotate
6. Tap **My Furniture** → **Scan New Object** to capture your own furniture with photogrammetry

## Thesis Document

The theoretical foundation (technologies, algorithms, architecture comparison) is available in [`TheoreticalFoundation.tex`](TheoreticalFoundation.tex).

## License

This project is part of an academic thesis and is not currently published under an open-source licence.
