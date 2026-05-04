# Thesis structure (reference outline)

**Augmented Reality-Based Interior Design** — Mara Ielciu

This file is the same outline as `content.tex` but readable as Markdown. The PDF table of contents comes from LaTeX (`\tableofcontents` + chapter files).

- Abstract  
- Table of contents  
- Context and Related Work (unnumbered section)

## 1 Introduction
- 1.1 Problem statement and goals  
- 1.2 Contributions  
- 1.3 Scope and assumptions  
- 1.4 Document structure  

## 2 Theoretical Foundations I: Photogrammetry, Depth Fusion, Apple APIs
- 2.1 Motivation  
- 2.2 Photogrammetry and classical pipeline (SfM, MVS, Poisson)  
- 2.3 Depth fusion and TSDF meshing  
- 2.4 Image-only vs depth-assisted reconstruction  
- 2.5 On-device capture pipeline (Object Capture, RoomPlan)  
- 2.6 Limitations  
- 2.7 Related work  

## 3 Theoretical Foundations II: 3D Gaussian Splatting
- 3.1 Representation of Gaussian primitives  
- 3.2 Projection, rasterisation, real-time rendering  
- 3.3 Differentiable rendering and training  
- 3.4 Meshes vs Gaussians in this application  

## 4 Requirements and System Specification
- 4.1 Stakeholders and use cases  
- 4.2 Functional requirements  
- 4.3 Non-functional requirements  
- 4.4 Platform and data specification  

## 5 Design, Implementation, and Testing
- 5.1 Architecture and modules  
- 5.2 Data flow and persistence  
- 5.3 Key implementation aspects  
- 5.4 User interface walkthrough  
- 5.5 Testing  

## 6 Conclusions

Bibliography  

Figure filenames: see **THESIS_FIGURES.md** (folder `figures/`).
