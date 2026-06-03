# Thesis TikZ Diagrams — Usage Guide

## 1. Add TikZ packages to main.tex (already done)

```latex
\usepackage{tikz}
\usetikzlibrary{arrows.meta, shapes.geometric, positioning, fit, calc}
```

Also add `decorations.pathreplacing` if you get errors on the brace decorations:
```latex
\usetikzlibrary{arrows.meta, shapes.geometric, positioning, fit, calc, decorations.pathreplacing}
```

---

## 2. How to replace a \thesisfig line

Each figure environment in the chapters has this pattern:

```latex
\begin{figure}[htbp]
\centering
\thesisfig{0.9\textwidth}{figures/FILENAME.pdf}
\caption{...}
\label{fig:LABEL}
\end{figure}
```

Replace the `\thesisfig` line with the matching `\input`:

```latex
\begin{figure}[htbp]
\centering
\input{tikz_diagrams/FILENAME}
\caption{...}
\label{fig:LABEL}
\end{figure}
```

---

## 3. Diagram → Chapter mapping

| TikZ file | Chapter | Figure label |
|-----------|---------|--------------|
| `ch2_photogrammetry_concept.tex` | Ch 2 | `fig:ch2_photo_concept` |
| `fig2_2_sfm_mvs.tex` | Ch 2 | `fig:ch2_photo_pipeline` |
| `fig2_3_dual_pipeline.tex` | Ch 2 | `fig:capture_branches` |
| `fig3_1_nerf_overview.tex` | Ch 3 | `fig:ch3_nerf_pipeline` |
| `fig3_2_gaussian_splatting_projection.tex` | Ch 3 | `fig:gaussian_project` |
| `ch4_context_diagram.tex` | Ch 4 | `fig:context_req` |
| `ch5_arch_layers.tex` | Ch 5 | `fig:architecture` |
| `ch5_domain_model.tex` | Ch 5 | `fig:domain_model` |
| `ch5_storage_layout.tex` | Ch 5 | `fig:storage_layout` |
| `ch5_dataflow.tex` | Ch 5 | `fig:dataflow` |
| `ch5_sharp_pipeline.tex` | Ch 5 | `fig:sharp_pipeline` |
| `ch5_splat_pipeline.tex` | Ch 5 | `fig:splat_pipeline` |
| `ch5_auth_flow.tex` | Ch 5 (**NEW**) | `fig:auth_flow` |

---

## 4. Adding the auth flow diagram (new figure)

Since `ch5_auth_flow.tex` is a new figure not yet in `chapter5_implementation.tex`,
add it where you describe the authentication system. Example:

```latex
\section{Authentication}
\label{sec:auth}

Users register and log in via email/password or Google OAuth\@.
Figure~\ref{fig:auth_flow} shows the full authentication flow.

\begin{figure}[htbp]
\centering
\input{tikz_diagrams/ch5_auth_flow}
\caption{Authentication flow: email registration and Google OAuth paths
converge on \texttt{UserManager} before admitting the user to the main hub.}
\label{fig:auth_flow}
\end{figure}
```

---

## 5. Editing tips

- Node styles are defined at the top of each `tikzpicture` — change colours, widths,
  or fonts there to restyle all nodes of a type at once.
- Adjust `node distance=` at the top to fan out or compress the whole diagram.
- Use `xshift` / `yshift` on individual nodes for fine positioning.
- The `arrow` style controls all arrowheads; `darrow` is the dashed variant.
