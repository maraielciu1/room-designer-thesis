//
//  GaussianSplattingGuideView.swift
//  RoomScanTest
//
//  Step-by-step in-app guide explaining how to train a Gaussian Splat
//  model externally and import the resulting .ply file back into the app.
//

import SwiftUI

struct GaussianSplattingGuideView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: TrainingMethod = .lumaAI

    enum TrainingMethod: String, CaseIterable, Identifiable {
        case lumaAI       = "Luma AI"
        case googleColab  = "Google Colab"
        case localMachine = "Local Machine"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .lumaAI:       return "globe"
            case .googleColab:  return "cloud"
            case .localMachine: return "desktopcomputer"
            }
        }

        var difficulty: String {
            switch self {
            case .lumaAI:       return "Easiest"
            case .googleColab:  return "Intermediate"
            case .localMachine: return "Advanced"
            }
        }

        var difficultyColor: Color {
            switch self {
            case .lumaAI:       return AppTheme.glowGreen
            case .googleColab:  return AppTheme.glowOrange
            case .localMachine: return AppTheme.glowRed
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Header
                        headerSection

                        //  Overview pipeline 
                        pipelineOverview

                        //  Step 1: Export from App 
                        stepCard(
                            number: 1,
                            title: "Export Images from the App",
                            icon: "square.and.arrow.up",
                            color: .blue,
                            content: {
                                AnyView(step1Content)
                            }
                        )

                        //  Step 2: Transfer to Computer 
                        stepCard(
                            number: 2,
                            title: "Transfer to Your Computer",
                            icon: "arrow.right.arrow.left",
                            color: AppTheme.glowCyan,
                            content: {
                                AnyView(step2Content)
                            }
                        )

                        //  Step 3: Train the Gaussian Splat 
                        stepCard(
                            number: 3,
                            title: "Train the Gaussian Splat",
                            icon: "cpu",
                            color: AppTheme.glowViolet,
                            content: {
                                AnyView(step3Content)
                            }
                        )

                        //  Step 4: Transfer .ply Back 
                        stepCard(
                            number: 4,
                            title: "Get the .ply File to iPhone",
                            icon: "iphone.and.arrow.forward",
                            color: AppTheme.glowOrange,
                            content: {
                                AnyView(step4Content)
                            }
                        )

                        //  Step 5: Import into App 
                        stepCard(
                            number: 5,
                            title: "Import into the App",
                            icon: "square.and.arrow.down",
                            color: AppTheme.glowGreen,
                            content: {
                                AnyView(step5Content)
                            }
                        )

                        //  Tips 
                        tipsSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("3DGS Training Guide")
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.warmAccent)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.glowViolet.opacity(0.12))
                    .frame(width: 90, height: 90)
                    .blur(radius: 24)
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.glowGreen, AppTheme.glowCyan],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(maxWidth: .infinity)

            Text("How to Train a Gaussian Splat")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)

            Text("Gaussian Splatting creates photorealistic 3D models using a different approach than Apple's Object Capture. Training happens on a computer, then you import the result.")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Pipeline Overview

    private var pipelineOverview: some View {
        VStack(spacing: 12) {
            ThemeSectionHeader(title: "Pipeline", icon: "arrow.triangle.branch")
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                pipelineStep(icon: "camera.fill", label: "Scan", color: .blue)
                pipelineArrow
                pipelineStep(icon: "square.and.arrow.up", label: "Export", color: AppTheme.glowCyan)
                pipelineArrow
                pipelineStep(icon: "cpu", label: "Train", color: AppTheme.glowViolet)
                pipelineArrow
                pipelineStep(icon: "square.and.arrow.down", label: "Import", color: AppTheme.glowOrange)
                pipelineArrow
                pipelineStep(icon: "eyes", label: "Compare", color: AppTheme.glowGreen)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .glassCard(cornerRadius: AppTheme.cardCornerRadius)
        }
    }

    private func pipelineStep(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(Circle())
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var pipelineArrow: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(AppTheme.tertiaryText)
    }

    // MARK: - Step Cards

    private func stepCard<Content: View>(
        number: Int,
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 28, height: 28)
                    .background(color)
                    .clipShape(Circle())

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()
            }

            content()
        }
        .padding(16)
        .glassCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    // MARK: - Step 1: Export

    private var step1Content: some View {
        VStack(alignment: .leading, spacing: 8) {
            guideText("After scanning an object and saving it, tap **\"Export Images for 3DGS Training\"** on the success screen.")
            guideText("The app packages all captured images into a **.zip** file and opens the iOS Share Sheet.")
            guideTip("💡 The images are only available right after scanning — export before tapping \"Done\"!")
        }
    }

    // MARK: - Step 2: Transfer

    private var step2Content: some View {
        VStack(alignment: .leading, spacing: 8) {
            guideText("Use one of these methods to get the .zip to your computer:")

            VStack(alignment: .leading, spacing: 6) {
                transferOption(icon: "airplayaudio", name: "AirDrop", detail: "Instant transfer to a Mac")
                transferOption(icon: "icloud", name: "iCloud Drive", detail: "Save to Files -> access from any device")
                transferOption(icon: "envelope", name: "Email / Messages", detail: "Send to yourself")
                transferOption(icon: "cable.connector", name: "USB Cable", detail: "Connect iPhone to Mac, use Finder")
            }
        }
    }

    private func transferOption(icon: String, name: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.warmAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(AppTheme.tertiaryText)
            }
        }
    }

    // MARK: - Step 3: Train

    private var step3Content: some View {
        VStack(alignment: .leading, spacing: 12) {
            guideText("Choose a training method:")

            // Method picker
            HStack(spacing: 6) {
                ForEach(TrainingMethod.allCases) { method in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMethod = method
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: method.icon)
                                .font(.system(size: 14))
                            Text(method.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                            Text(method.difficulty)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(method.difficultyColor)
                        }
                        .foregroundColor(selectedMethod == method ? .white : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedMethod == method
                            ? AnyShapeStyle(method.difficultyColor.opacity(0.2))
                            : AnyShapeStyle(AppTheme.lightNeutral.opacity(0.06))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    selectedMethod == method ? method.difficultyColor.opacity(0.4) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }

            // Method-specific instructions
            switch selectedMethod {
            case .lumaAI:       lumaInstructions
            case .googleColab:  colabInstructions
            case .localMachine: localInstructions
            }
        }
    }

    private var lumaInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            guideSubtitle("Luma AI (Web-Based)")
            numberedStep(1, "Go to **lumalabs.ai/interactive-scenes** in your browser")
            numberedStep(2, "Create a free account and click **\"New Capture\"**")
            numberedStep(3, "Upload your exported images (unzip first)")
            numberedStep(4, "Wait ~5–15 minutes for processing")
            numberedStep(5, "Download the result as a **.ply** file")
            guideTip("✅ No GPU required! Works entirely in the cloud.")
        }
    }

    private var colabInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            guideSubtitle("Google Colab (Free GPU)")
            numberedStep(1, "Open **colab.research.google.com**")
            numberedStep(2, "Search for **\"gaussian-splatting colab\"** notebooks (e.g. from camenduru)")
            numberedStep(3, "Upload your .zip of images to the Colab runtime")
            numberedStep(4, "The notebook runs **COLMAP** (camera pose estimation) then **3D Gaussian Splatting** training")
            numberedStep(5, "Download the output **point_cloud.ply** from the output folder")
            guideTip("⏱ Takes ~20–40 min on a free T4 GPU. Use 7,000–30,000 iterations.")

            codeSnippet("""
            # Typical Colab commands:
            !pip install plyfile torch
            !git clone --recursive \\
              https://github.com/graphdeco-inria/gaussian-splatting
            !python train.py -s /content/data -i 7000
            # Output: output/<run>/point_cloud/iteration_7000/point_cloud.ply
            """)
        }
    }

    private var localInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            guideSubtitle("Local Machine (NVIDIA GPU)")
            guideText("Requires: **NVIDIA GPU** (≥ 8 GB VRAM), **CUDA**, **COLMAP**, **Python 3.8+**")
            numberedStep(1, "Install COLMAP (colmap.github.io)")
            numberedStep(2, "Clone the 3DGS repo:\n`git clone --recursive https://github.com/graphdeco-inria/gaussian-splatting`")
            numberedStep(3, "Organize images:\n`data/input/<your images>`")
            numberedStep(4, "Run: `python train.py -s data/ --iterations 30000`")
            numberedStep(5, "Output: `output/<run>/point_cloud/iteration_30000/point_cloud.ply`")
            guideTip("🚀 Best quality. Nerfstudio (`nerfstudio.github.io`) is a user-friendly alternative.")
        }
    }

    // MARK: - Step 4: Transfer Back

    private var step4Content: some View {
        VStack(alignment: .leading, spacing: 8) {
            guideText("Get the **.ply** file from your computer to your iPhone:")

            VStack(alignment: .leading, spacing: 6) {
                transferOption(icon: "airplayaudio", name: "AirDrop", detail: "Fastest — right-click the .ply -> AirDrop -> your iPhone")
                transferOption(icon: "icloud", name: "iCloud Drive", detail: "Save to iCloud -> open Files app on iPhone")
                transferOption(icon: "envelope", name: "Email", detail: "Email the .ply to yourself -> open on iPhone")
                transferOption(icon: "externaldrive.connected.to.line.below", name: "Direct download", detail: "If using Luma AI, download directly in Safari on iPhone")
            }

            guideTip("📱 The .ply file will be accessible through the Files app on your iPhone.")
        }
    }

    // MARK: - Step 5: Import

    private var step5Content: some View {
        VStack(alignment: .leading, spacing: 8) {
            guideText("There are two places to import a .ply file:")

            VStack(alignment: .leading, spacing: 10) {
                importOption(
                    title: "From the Furniture Library",
                    detail: "Tap the ✨ sparkle button on any scanned object -> select your .ply file"
                )
                importOption(
                    title: "From the Comparison View",
                    detail: "Open a scanned object -> tap ⋯ menu -> \"Import .ply Splat\""
                )
            }

            guideText("Once imported, you can view the Gaussian Splat alongside the Object Capture model in the **side-by-side comparison**.")
            guideTip("✅ The app parses the .ply file and displays key stats (Gaussian count, file size, etc.)")
        }
    }

    private func importOption(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.glowGreen)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(AppTheme.tertiaryText)
            }
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemeSectionHeader(title: "Tips for Better Results", icon: "lightbulb")
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 10) {
                tipRow(icon: "camera.fill", text: "Take **50+ images** from diverse angles for best quality")
                tipRow(icon: "sun.max.fill", text: "**Even lighting** reduces artifacts; avoid harsh shadows")
                tipRow(icon: "arrow.triangle.2.circlepath", text: "Walk a full **360° circle** around the object")
                tipRow(icon: "timer", text: "More training **iterations** = better quality (but slower)")
                tipRow(icon: "rectangle.compress.vertical", text: "Start with **7,000 iterations** for a quick test, up to **30,000** for best quality")
            }
            .padding(16)
            .glassCard(cornerRadius: AppTheme.cardCornerRadius)
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.glowOrange)
                .frame(width: 20)
                .padding(.top, 2)
            Text(.init(text))   // .init enables markdown parsing
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
    }

    // MARK: - Reusable Text Helpers

    private func guideText(_ text: String) -> some View {
        Text(.init(text))
            .font(.caption)
            .foregroundColor(AppTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func guideSubtitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.primaryText)
    }

    private func guideTip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(AppTheme.glowGreen)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.glowGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func numberedStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.warmAccent)
                .frame(width: 16, alignment: .trailing)
            Text(.init(text))
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func codeSnippet(_ code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(AppTheme.glowCyan.opacity(0.8))
                .padding(10)
        }
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.glowCyan.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    GaussianSplattingGuideView()
        .preferredColorScheme(.dark)
        .appSheetBackground()
}
