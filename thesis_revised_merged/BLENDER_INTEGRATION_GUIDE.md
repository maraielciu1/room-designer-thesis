# Where to mention Blender room export in the **unrevised** thesis

This guide applies to `thesis.tex` and `chapters/chapter*.tex` (original files). The merged chapters in this folder already include Blender content. Use these suggestions when you prefer to patch the original thesis incrementally rather than switching to `merged_thesis.tex`.

**Implementation reference:** `RoomScanTest/Services/RoomBlenderExportService.swift` — invoked from `RoomDesignerView` (toolbar) and `RoomListView` (context menu).

---

## 1. `thesis.tex` — Abstract (lines ~55–57)

Add **one sentence** after the persistence / 3DGS sentence, for example:

> Completed room designs can be exported as a ZIP archive containing a glTF scene, USDZ furniture copies, JSON placement manifests, and a Blender Python script for further editing in desktop DCC tools.

Also extend the closing “main contribution” sentence to mention “optional Blender hand-off” alongside plenoptic visualisation.

---

## 2. `chapters/chapter1_introduction.tex`

| Location | What to add |
|----------|-------------|
| **§Motivation** (after asset-authoring paragraph, ~lines 78–87) | Short paragraph: RoomPlan boxes are not CAD; users who need renders, lighting tweaks, or mesh cleanup benefit from exporting the **same staged scene** the editor uses (not raw `CapturedRoom` JSON alone). |
| **Objectives enumerate** (~lines 103–144) | New item **(5) DCC export** or fold into “Persistent virtual staging”: export glTF + USDZ ZIP with Blender helper script. Renumber if you add analytics as a separate objective. |
| **Contributions list** (~lines 153–189) | Bullet: *Blender-oriented export service* packaging glTF, manifests, `blender_apply_furniture.py`, share sheet. |
| **Document structure** (~line 202) | Mention Blender export in the implementation chapter bullet. |

---

## 3. `chapters/chapter2.tex`

| Location | What to add |
|----------|-------------|
| **Table `tab:feature_api`** (~lines 223–241) | New row: `Blender export` → `ZIP (glTF + USDZ + script)` → `DCC hand-off`. |
| **§Limitations** (~line 247) | Replace vague “export to external tools” with: *optional export to Blender for refinement; parametric RoomPlan geometry is exported as glTF boxes and markers, with USDZ furniture applied via post-import script.* |

---

## 4. `chapters/chapter3.tex`

| Location | What to add |
|----------|-------------|
| **§Meshes versus Gaussians** (~lines 190–226) | One sentence: Blender export includes **mesh-based** staging (structure + USDZ); **does not** bundle `.ply` splats—splats remain in-app benchmarks unless imported manually in Blender. |
| **Reconstruction spectrum closing** (~lines 360–364) | Append: `→ Blender export (staged mesh hand-off)`. |

---

## 5. `chapters/chapter4.tex`

| Location | What to add |
|----------|-------------|
| **Use cases** (~lines 12–15) | **UC-8:** Export staged room as Blender ZIP from list or editor. |
| **Functional requirements** (after R-10) | **R-12 Blender export** — draft: |
| | *The system shall export a saved room with scan data as a shareable ZIP containing: (a) glTF scene in metres with placement markers; (b) USDZ furniture and wall-art copies; (c) JSON manifests; (d) `blender_apply_furniture.py` and README.* |
| **Figure `fig:context_req` caption** (~line 124) | Add “Blender export ZIP” to the artefact list. |
| **Table `tab:req_trace`** | Row R-12; extend N-2 privacy note: Blender export stays on-device. |
| **Risk table** | Optional row: export without scan data → disable + alert. |

---

## 6. `chapters/chapter5_implementation.tex` (most detail here)

Add a dedicated subsection **§Blender export** (~½–1 page) after SHARP or before UI walkthrough:

1. **Entry points:** `RoomDesignerView`, `RoomListView`; progress overlay; share sheet.
2. **`RoomBlenderExportService.makeExportZip`:** temp directory → ZIP contents (glTF, bin, furniture/, manifests, script, README).
3. **`GltfMiniBuilder`:** structural boxes, green markers, metre units.
4. **`blender_apply_furniture.py`:** import USDZ on markers, spawn lights, remove guides.
5. **`materialsForListExport`:** list vs editor material resolution.

| Also update | |
|-------------|--|
| **Architectural overview / storage figure caption** | Mention export ZIP in artefact list. |
| **§User interface walkthrough** | Demo step: Export for Blender → share → import in Blender → run script. |
| **Demonstration checklist** (~lines 269–287) | New step for R-12. |
| **Table `tab:test_map`** | Row: export ZIP, Blender import, script alignment. |
| **§Summary** (~line 340) | One sentence on DCC hand-off. |

Optional figure (see `THESIS_FIGURES.md`): `figures/ch5_blender_export_flow.pdf` — RoomPlan → editor → ZIP → Blender → script.

---

## 7. `chapters/chapter6_conclusions.tex`

| Location | What to add |
|----------|-------------|
| **§Summary of Results** (~lines 11–13) | Sentence on Blender export extending staging beyond RealityKit. |
| **§Limitations** | Export is mesh-based; splats not in ZIP; Blender workflow assumes user has desktop Blender. |
| **§Future Work** | Optional: export splats or automatic alignment of splats to exported room coordinates. |

---

## 8. Optional: `chapters/state_of_the_art.tex`

If you include the extended survey chapter, one paragraph under consumer AR / tooling: mobile apps rarely offer **metric room export to DCC**; this project’s ZIP bridge fills that gap for thesis evaluation.

---

## Suggested requirement text (copy-paste ready)

```latex
\item[R-12 Blender export.]
The system shall export a saved room that has scan data as a shareable ZIP
containing: (a)~a glTF scene with structural geometry and furniture placement
markers in metres; (b)~copies of USDZ furniture and wall-art images;
(c)~\texttt{scene\_manifest.json} and \texttt{furniture\_manifest.json};
(d)~\texttt{blender\_apply\_furniture.py} and \texttt{README.txt} with import
instructions. Export shall be available from the room list and the room designer.
```

---

## Demo sentence for implementation chapter

> From the room list or designer, choose *Export for Blender*, share the ZIP, import `room_scene.gltf` in Blender, run `blender_apply_furniture.py` from the extracted folder, and verify furniture aligns to green markers at metre scale.

---

For a full formal draft with Blender already integrated, compile `thesis_revised_merged/merged_thesis.tex` instead of patching line by line.
