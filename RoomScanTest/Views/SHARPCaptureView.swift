//
//  SHARPCaptureView.swift
//  RoomScanTest
//
//  Single-image Gaussian Splat generation via Apple's SHARP model.
//  Flow: configure server URL → take one photo → server returns .ply → GaussianSplatView
//

import SwiftUI

// MARK: - Main View

struct SHARPCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    // Phase machine
    @State private var phase: Phase = .ready
    @State private var capturedImage: UIImage?
    @State private var resultPlyURL: URL?
    @State private var errorMessage: String?

    // Server
    @State private var serverReachable: Bool? = nil   // nil = still checking
    @State private var serverURLInput: String = SHARPService.serverBaseURL ?? ""
    @State private var showURLEditor = false

    // Camera sheet
    @State private var showCamera = false

    enum Phase { case ready, processing, done }

    var body: some View {
        ZStack {
            Color(hex: 0x0B0D17).ignoresSafeArea()

            switch phase {
            case .ready:      readyView
            case .processing: processingView
            case .done:
                if let url = resultPlyURL {
                    GaussianSplatView(plyURL: url)
                }
            }
        }
        .navigationTitle("SHARP Capture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(hex: 0x0B0D17).opacity(0.88), for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showURLEditor = true
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.accentGradientInline)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePickerView(image: $capturedImage)
        }
        .sheet(isPresented: $showURLEditor) {
            serverURLSheet
        }
        .task { await checkServer() }
    }

    // MARK: - Ready state

    private var readyView: some View {
        ScrollView {
            VStack(spacing: 28) {

                // Hero icon
                ZStack {
                    Circle()
                        .fill(AppTheme.glowBlue.opacity(0.12))
                        .frame(width: 130, height: 130)
                        .blur(radius: 32)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(AppTheme.accentGradientInline)
                }
                .padding(.top, 32)

                // Title
                VStack(spacing: 8) {
                    Text("SHARP Monocular Capture")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    Text("Take one photo — SHARP reconstructs a full 3D Gaussian Splatting scene in seconds using a single feedforward pass.")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                // Server status card
                serverStatusCard
                    .padding(.horizontal, 24)

                // Captured image preview
                if let img = capturedImage {
                    capturedPreview(img)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label(capturedImage == nil ? "Take Photo" : "Retake",
                              systemImage: "camera.fill")
                    }
                    .buttonStyle(capturedImage == nil
                                 ? AnyButtonStyle(GradientButtonStyle())
                                 : AnyButtonStyle(GhostButtonStyle()))

                    if capturedImage != nil {
                        Button {
                            Task { await runInference() }
                        } label: {
                            Label("Generate Gaussian Splat", systemImage: "sparkles")
                        }
                        .buttonStyle(GradientButtonStyle())
                        .disabled(serverReachable != true)

                        if serverReachable == false {
                            Text("Start sharp_server.py on your Mac first")
                                .font(.caption)
                                .foregroundColor(AppTheme.glowOrange)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                // Error bubble
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(AppTheme.glowOrange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Server status card

    private var serverStatusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColour.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: statusIcon)
                    .font(.system(size: 17))
                    .foregroundColor(statusColour)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }
            Spacer()
            // Re-check button
            Button {
                Task { await checkServer() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.tertiaryText)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }

    private var statusColour: Color {
        switch serverReachable {
        case .none:  return AppTheme.glowBlue
        case true:   return AppTheme.glowGreen
        case false:  return AppTheme.glowOrange
        }
    }
    private var statusIcon: String {
        switch serverReachable {
        case .none:  return "clock"
        case true:   return "checkmark.seal.fill"
        case false:  return "exclamationmark.triangle.fill"
        }
    }
    private var statusTitle: String {
        switch serverReachable {
        case .none:  return "Checking Server…"
        case true:   return "SHARP Server Online"
        case false:  return "Server Not Reachable"
        }
    }
    private var statusSubtitle: String {
        let url = SHARPService.serverBaseURL ?? "not set"
        switch serverReachable {
        case .none:  return url
        case true:   return url
        case false:  return "Run sharp_server.py in sharp_env · tap ⚙ for URL"
        }
    }

    // MARK: - Captured image preview

    private func capturedPreview(_ img: UIImage) -> some View {
        Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .frame(height: 210)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.10), lineWidth: 1))
            .padding(.horizontal, 24)
    }

    // MARK: - Processing overlay

    private var processingView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(AppTheme.glowBlue.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .blur(radius: 24)
                ProgressView()
                    .tint(AppTheme.glowCyan)
                    .scaleEffect(1.5)
            }
            VStack(spacing: 10) {
                Text("Generating Splat…")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                Text("SHARP is building a 3D Gaussian Splatting scene from your single image.")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Text("First run: ~2 min (Metal shaders compile once). After that: ~10 s.")
                    .font(.caption)
                    .foregroundColor(AppTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }

    // MARK: - Server URL sheet

    private var serverURLSheet: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SHARP Server URL")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Enter the base URL of your Mac running sharp_server.py. Use your Mac's local WiFi IP address.")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                        TextField("http://192.168.1.x:8765", text: $serverURLInput)
                            .textFieldStyle(.plain)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                            .padding(12)
                            .glassCard(cornerRadius: 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    Button("Save & Check") {
                        SHARPService.serverBaseURL = serverURLInput
                        showURLEditor = false
                        Task { await checkServer() }
                    }
                    .buttonStyle(GradientButtonStyle())

                    Spacer()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: 0x0B0D17), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showURLEditor = false }
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
    }

    // MARK: - Logic

    private func checkServer() async {
        serverReachable = nil
        serverReachable = await SHARPService.ping()
    }

    private func runInference() async {
        guard let image = capturedImage else { return }
        phase = .processing
        errorMessage = nil
        do {
            resultPlyURL = try await SHARPService.infer(image: image)
            phase = .done
        } catch {
            errorMessage = error.localizedDescription
            phase = .ready
        }
    }
}

// MARK: - Type-erased ButtonStyle helper

private struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (ButtonStyle.Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Camera picker (UIImagePickerController)

private struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let img = info[.originalImage] as? UIImage { parent.image = img }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SHARPCaptureView()
    }
    .preferredColorScheme(.dark)
}
