# Thesis Edit Log

All changes made to `.tex` files in `chapters/` and to `main.tex`. Listed by file, with exact location and reason.

---

## `chapters/main.tex`

### 1. Abstract — incorrect limitation description (line 40)
**What:** The opening sentence said "requiring the user to be physically present for every design iteration and providing no persistent scene model." This partially duplicates Chapter 1 word-for-word, which reduces the abstract's value.  
**Fix:** Rewrote to a cleaner, slightly distinct formulation: "provide no persistent room model, and require the user to be physically present… The result is a tool suited to a single in-store moment…"

### 2. Abstract — contribution count was wrong (line 40 / 42)
**What:** Said "four original contributions" but the body paragraph listed five (the DCC export was tacked on as "Another contribution is…" which read like an afterthought).  
**Fix:** Changed to "five engineering contributions" and made the DCC export a numbered fifth contribution with a clean sentence.

---

## `chapters/chapter1_introduction.tex`

### 3. Objective 5 — stub text, not a proper sentence (lines 106–108)
**What:** The DCC export objective read as a note: `"Persistent virtual staging: export glTF + USDZ ZIP with Blender helper script."` — no justification, incomplete phrasing.  
**Fix:** Replaced with a full objective paragraph including an **Emph{Justification}** clause consistent with the style of Objectives 1–4.

### 4. Contributions bullet — incomplete wording (line 148)
**What:** The Blender export bullet in the Contributions list read: `"Blender-oriented export service packaging glTF, manifests, python scipt, share sheet."` — note-style, typo ("scipt"), no article.  
**Fix:** Rewritten as a complete sentence: "A Blender-oriented export service that packages the staged room as a shareable ZIP containing a glTF scene, USDZ furniture copies, wall-art images, JSON manifests, and a Python helper script for automated Blender import."

---

## `chapters/state_of_the_art.tex`

### 5. Chapter roadmap paragraph — missing (after line 15)
**What:** Chapters 3 (3DGS) has an explicit "Chapter roadmap" paragraph but the related work chapter did not, making the structure inconsistent.  
**Fix:** Added a `\paragraph{Chapter roadmap.}` after the introductory paragraph, explaining how each section builds toward the gap table.

### 6. SUS threshold incorrect, wrong citation (lines 181–183)
**What:** "a score above 70 is conventionally considered acceptable and above 85 is excellent~\cite{kandil2021ux}" — two errors: (a) the standard published threshold is **68**, not 70; (b) the citation was to Kandil et al.'s AR study, which *uses* SUS but does not *define* its thresholds.  
**Fix:** Changed threshold to 68, added a `\footnote` explaining the source (Bangor et al. 2008 calibration study, `\cite{bangor2008sus}`), and removed the misattributed `\cite{kandil2021ux}` from this specific sentence.

### 7. Table 2.1 caption — category mismatch not flagged (line 294)
**What:** Table 2.1 rows mix deployable end-user apps (IKEA Place, Kán et al.) with research pipelines (ScanNet, standalone 3DGS). A reader could misread the comparison.  
**Fix:** Extended the caption with a clarifying note: "Note: ScanNet and the standalone 3DGS pipeline are research-grade offline tools rather than deployable end-user applications; they are included to characterise the capability gap…"

### 8. Gap section — no explicit link back to thesis objectives (end of section 2.6)
**What:** The gap table and text identified what is missing but never explicitly connected the gap to the five numbered objectives in Chapter 1.  
**Fix:** Added a closing sentence: "This gap directly motivates the five objectives stated in Chapter 1: semantic capture (Objective 1), persistent off-site editing (Objective 2), on-device asset authoring (Objective 3), Gaussian splat viewing (Objective 4), and DCC export (Objective 5)."

---

## `chapters/chapter2.tex` (Photogrammetry chapter)

### 9. Chapter roadmap paragraph — missing (after introductory paragraph)
**What:** No roadmap paragraph while chapter3.tex has one — inconsistent style.  
**Fix:** Added a `\paragraph{Chapter roadmap.}` listing the six sections by reference.

### 10. Figure 3.2 caption — low-quality citation `\cite{Kholil_2021}` (line 46)
**What:** The SfM→MVS→Poisson pipeline diagram was attributed to a low-impact 2021 IOP conference paper (Khalid et al.) which postdates the pipeline by a decade. The standard citations for each stage (SIFT, PMVS, Poisson, photogrammetry textbook) were already present in the document.  
**Fix:** Replaced `(adapted from \cite{Kholil_2021})` with "Pipeline stages follow the standard formulation in~\cite{luhmann2014photogrammetry,lowe2004sift,furukawa2010pmvs,kazhdan2006poisson}."

---

## `chapters/chapter3.tex` (3DGS chapter)

### 11. Chapter opening — abrupt NeRF-to-3DGS transition (lines 2–8)
**What:** The chapter is titled "3D Gaussian Splatting" but opened mid-thought on NeRF without a bridge sentence. The transition "Training and rendering were initially slow." was a single choppy sentence.  
**Fix:** Added an explicit bridge: "Before introducing 3D Gaussian Splatting it helps to recall the volumetric representation it replaces." and expanded the NeRF limitation sentence: "Training required hours of GPU time and rendering was far from real-time, motivating the shift towards explicit, rasterisable representations."

---

## `chapters/chapter5_implementation.tex`

### 12. Duplicate table — `tab:test_map` appeared twice (lines 328–353 and 547–569)
**What:** The "Complete requirement-to-test mapping" table (R-1 through R-10) was copy-pasted and appeared identically at the end of Section 6.9.1 (Functional tests) and again after Section 6.9.6 (Efficient 3DGS experiment design). Both had `\label{tab:test_map}`, causing a multiply-defined label LaTeX warning and redundant content.  
**Fix:** Removed the second (duplicate) instance entirely. The first remains in Section 6.9.1 where it belongs.

### 13. Demonstration checklist — optional/required items not distinguished (Section 6.8.2)
**What:** Items 5, 6, 7 were marked "(optional)" inline within a flat numbered list, making it hard to tell at a glance what is required for full requirement traceability versus what requires additional hardware.  
**Fix:** Split into two explicit sublists: **"Core flow (required for full traceability)"** (items 1–5) and **"Optional extensions (require additional hardware or server)"** (items 6–8). Also fixed the `pauseARSession:` call to show the full parameter name `pauseARSession: true` consistently with the walkthrough text.

---

## `chapters/chapter6_conclusions.tex`

### 14. Future Work — run-on sentence, missing punctuation (line 16)
**What:** "…semantic suggestions informed by work such as Kán et al. \cite{kan2021ar} Mithun et al. \cite{Geo2023} demonstrate that…" — two independent clauses were joined without any punctuation, making the sentence grammatically broken.  
**Fix:** Split into two sentences: the first ends the list of extensions (…such as Kán et al.); the second starts a new sentence: "Mithun et al. demonstrate that synthetic datasets…"  
Also improved the final bullet of extensions from "level-of-detail for large splats" to the more precise "level-of-detail rendering for large splat clouds."

---

## All SUS/HARUS mentions removed (across 4 files)

**Rationale:** The thesis never conducts a SUS or HARUS evaluation — it only cites Kandil et al.'s *findings* to motivate design choices. Explaining SUS scoring thresholds in detail (and debating 68 vs 70) adds nothing to the argument. The Kandil citation is kept wherever it motivates design decisions; only the instrument mechanics and score thresholds are removed.

| File | What was removed |
|---|---|
| `state_of_the_art.tex` | Entire SUS/HARUS definition paragraph with scores and footnote → replaced with one clean sentence describing the instruments at a high level |
| `state_of_the_art.tex` | "formal SUS/HARUS evaluation" → "formal usability evaluation" |
| `chapter1_introduction.tex` | "baseline for future usability studies using SUS and HARUS" → "baseline for future formal usability studies" |
| `chapter6_conclusions.tex` | "Usability has not been quantified with SUS/HARUS" → "Usability has not been formally evaluated" |
| `references.bib` | Removed the `bangor2008sus` entry (added in the previous round, now unreferenced) |

---

## What was NOT changed (and why)

| Issue | Decision |
|---|---|
| Table 4.3 inference time `-1×` | Already correct in `.tex` as "Minutes to hours" — the `-1×` was a rendering artifact in an older PDF version |
| `GaussianSplatData.swift` depth sort | Already correct in `.tex`: sorting attributed to `GaussianSplatRenderer.swift`, not to the parser |
| `DecorManager` in architecture diagram | Could not confirm absence without reading all untracked Swift files; left unchanged to avoid introducing a new inaccuracy |
| `POST /sharp/infer` vs `POST /jobs` endpoint | Both the SHARP-specific `SHARPService` (`/sharp/infer`) and the generic `GaussianSplatCloudService` (`/jobs`) can coexist. The thesis describes the SHARP-specific path which may be in `SHARPService.swift` (not among the git-tracked files I could read). Left unchanged pending code verification. |
| Duplicate SHARP bibliography entries `[MDC+25]` / `[MDL+25]` | Those entries are in an external bib file not inside `chapters/references.bib`; could not edit without seeing the full bib. Flag for manual review. |

---

## Gaussian Splatting Experiments (not implemented — for future work)

These are concrete experiments worth adding to the future work section or running before submission:

1. **Opacity pruning threshold sweep** — vary the server-side cutoff from 0.001 to 0.05, record splat count, on-device FPS, and PSNR vs. the unpruned reference. Directly supports the ≤300k Gaussian target (N-1).
2. **SHARP vs. COLMAP+3DGS quality comparison** — same room, both pipelines; evaluate on held-out views with PSNR / SSIM / LPIPS. Addresses the "forward-looking comparison" the thesis promises but doesn't perform.
3. **Tile-based depth sort** — sort within spatial cells rather than globally; measure frame-time savings at 120k and 300k splat counts.
4. **Spherical harmonic degree impact** — retrain same interior scene with SH degree 0/1/2/3; measure PSNR gain vs. file size. Justifies the degree-0-only choice used by SHARP.
5. **Image count vs. Object Capture quality** — 20/40/72/120/200 images for the same object; measure bounding-box IoU and dimension MAE. Adds a coverage curve to Section 6.9.4.
6. **RoomPlan-anchored SHARP scale correction** — use known room dimensions from `CapturedRoom` to add a metric scale factor to the SHARP output; measure position error reduction.
7. **Multi-frame SHARP fusion** — run SHARP on 5–10 frames, ICP-align and merge the PLYs; compare coverage vs. single-image SHARP and full COLMAP run.
8. **Coordinate transform: GPU vs. CPU** — move the COLMAP→Y-up flip from the CPU parser to the Metal vertex shader; measure load-time and frame-time difference.
