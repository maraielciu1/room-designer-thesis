# Merged thesis chapters

This folder contains a **formal merge** of:

- Original chapters (`chapters/chapter*.tex`, `thesis.tex` tone and structure)
- Revised chapters (`chapters/revised_chapter*.tex`, lifecycle narrative, three-asset comparison, analytics, Blender export)

The revised drafts were intentionally more conversational; the merged versions keep the original academic register while incorporating new technical content (R-11, R-12, Assets A/B/C, SHARP, statistics, Blender).

## Compile

From the **project root** (where `style.sty` and `references.bib` live):

```bash
# From project root (where style.sty and references.bib live):
pdflatex thesis_revised_merged/merged_thesis
bibtex merged_thesis
pdflatex thesis_revised_merged/merged_thesis
pdflatex thesis_revised_merged/merged_thesis
```

## Files

| File | Source blend |
|------|----------------|
| `chapter1_introduction.tex` | Original motivation + revised objectives (analytics, Blender, three assets) |
| `chapter2_capture_theory.tex` | Original Ch.2 + TSDF fusion note + Blender in limitations |
| `chapter3_gaussian_splatting.tex` | Original Ch.3 (NeRF/SHARP depth) + formal three-asset table |
| `chapter4_requirements.tex` | Original requirements + R-11/R-12, extended use cases |
| `chapter5_implementation.tex` | Original Metal/SHARP detail + analytics & Blender sections |
| `chapter6_conclusions.tex` | Original conclusions + reconstruction comparison |

## Blender export in the **unrevised** `thesis.tex` / `chapters/*.tex`

See `BLENDER_INTEGRATION_GUIDE.md` in this folder for line-level suggestions on where to add Blender mentions without adopting the full revised draft.

Original files under `chapters/` are **not modified**; integrate from here when ready.
