//
//  Room3DGSCaptureView.swift
//  RoomScanTest
//
//  Multi-frame room capture for 3D Gaussian Splatting via backend_3dgs.
//  Flow: configure server URL → capture frames → zip → upload → view .ply
//

import SwiftUI
import AVFoundation

// MARK: - Main View

struct Room3DGSCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    private static let minFrames = 20

    @State private var phase: Phase = .capture
    @State private var framesDirectory: URL?
    @State private var frameCount = 0
    @State private var resultPlyURL: URL?
    @State private var errorMessage: String?
    @State private var uploadProgress: String?

    @State private var serverReachable: Bool?
    @State private var serverURLInput: String = GaussianSplatCloudConfig.serverBaseURL ?? ""
    @State private var showURLEditor = false
    @State private var captureTrigger = 0

    enum Phase { case capture, uploading, done }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            switch phase {
            case .capture:
                capturePhase
            case .uploading:
                uploadingView
            case .done:
                if let url = resultPlyURL {
                    GaussianSplatView(plyURL: url)
                }
            }
        }
        .navigationTitle("3D Gaussian Splat")
        .navigationBarTitleDisplayMode(.inline)
        .appNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
            if phase == .done, let url = resultPlyURL {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: url, preview: SharePreview("3DGS Scene (.ply)", image: Image(systemName: "cube"))) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.accentGradientInline)
                    }
                }
            }
            if phase == .capture {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showURLEditor = true } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.accentGradientInline)
                    }
                }
            }
        }
        .sheet(isPresented: $showURLEditor) {
            serverURLSheet
        }
        .onAppear { prepareSessionDirectory() }
        .onDisappear { cleanupSessionDirectory() }
        .task { await checkServer() }
    }

    // MARK: - Capture phase

    private var capturePhase: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if let dir = framesDirectory {
                    RoomFrameCameraView(
                        framesDirectory: dir,
                        captureTrigger: captureTrigger,
                        onFrameSaved: refreshFrameCount
                    )
                    .ignoresSafeArea(edges: .top)
                } else {
                    ProgressView("Starting camera…")
                        .tint(AppTheme.glowCyan)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Button {
                    captureTrigger += 1
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.55), lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 58, height: 58)
                    }
                }
                .padding(.bottom, 12)
                .disabled(framesDirectory == nil)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 280)
            .layoutPriority(1)

            VStack(spacing: 12) {
                serverStatusCard
                    .padding(.horizontal, 16)

                HStack {
                    Label("\(frameCount) frames", systemImage: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text("Need \(Self.minFrames)+")
                        .font(.caption)
                        .foregroundColor(
                            frameCount >= Self.minFrames ? AppTheme.glowGreen : AppTheme.secondaryText
                        )
                }
                .padding(.horizontal, 20)

                Button {
                    Task { await uploadAndTrain() }
                } label: {
                    Label("Upload & Train", systemImage: "cloud.fill")
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal, 24)
                .disabled(frameCount < Self.minFrames || serverReachable != true)

                if frameCount < Self.minFrames {
                    Text("Walk around the room and tap the shutter for each viewpoint.")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                if serverReachable == false {
                    Text("Start backend_3dgs on your laptop · tap ⚙ for URL")
                        .font(.caption)
                        .foregroundColor(AppTheme.glowOrange)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(AppTheme.glowOrange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 16)
            .background(AppTheme.background)
        }
    }

    // MARK: - Server status

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
                    .foregroundStyle(AppTheme.primaryText)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Button { Task { await checkServer() } } label: {
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
        case .none: return AppTheme.glowBlue
        case true: return AppTheme.glowGreen
        case false: return AppTheme.glowOrange
        }
    }

    private var statusIcon: String {
        switch serverReachable {
        case .none: return "clock"
        case true: return "checkmark.seal.fill"
        case false: return "exclamationmark.triangle.fill"
        }
    }

    private var statusTitle: String {
        switch serverReachable {
        case .none: return "Checking Server…"
        case true: return "3DGS Server Online"
        case false: return "Server Not Reachable"
        }
    }

    private var statusSubtitle: String {
        let url = GaussianSplatCloudConfig.serverBaseURL ?? "not set"
        switch serverReachable {
        case .none, true: return url
        case false: return "Run app.py from backend_3dgs on your Mac"
        }
    }

    // MARK: - Uploading

    private var uploadingView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(AppTheme.glowGreen.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .blur(radius: 24)
                ProgressView()
                    .tint(AppTheme.glowCyan)
                    .scaleEffect(1.5)
            }
            VStack(spacing: 10) {
                Text("Training Splat…")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(uploadProgress ?? "Uploading frames to your laptop…")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Text("COLMAP + 3DGS can take 30–90 minutes depending on your GPU.")
                    .font(.caption)
                    .foregroundColor(AppTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }

    // MARK: - Settings sheet

    private var serverURLSheet: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3DGS Server URL")
                            .font(.headline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text("HTTPS base URL of your laptop running backend_3dgs (app.py). Use your Mac's Wi‑Fi IP, e.g. https://192.168.1.x:5001")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                        TextField("https://192.168.1.x:5001", text: $serverURLInput)
                            .textFieldStyle(.plain)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(12)
                            .glassCard(cornerRadius: 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    Button("Save & Check") {
                        GaussianSplatCloudConfig.serverBaseURL = serverURLInput
                        showURLEditor = false
                        Task { await checkServer() }
                    }
                    .buttonStyle(GradientButtonStyle())

                    Spacer()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showURLEditor = false }
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
    }

    // MARK: - Logic

    private func prepareSessionDirectory() {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("Room3DGSCapture", isDirectory: true)
        let session = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        framesDirectory = session
        refreshFrameCount()
    }

    private func cleanupSessionDirectory() {
        guard let dir = framesDirectory else { return }
        try? FileManager.default.removeItem(at: dir)
        framesDirectory = nil
    }

    private func refreshFrameCount() {
        guard let dir = framesDirectory else {
            frameCount = 0
            return
        }
        frameCount = ImageExportService.imageCount(in: dir)
    }

    private func checkServer() async {
        serverReachable = nil
        guard let url = GaussianSplatCloudConfig.serverURL else {
            serverReachable = false
            return
        }
        serverReachable = await GaussianSplatCloudService.ping(serverBaseURL: url)
    }

    private func uploadAndTrain() async {
        guard let dir = framesDirectory else { return }
        guard let serverURL = GaussianSplatCloudConfig.serverURL else {
            errorMessage = "Set your 3DGS server URL in Settings (⚙)."
            return
        }
        guard frameCount >= Self.minFrames else { return }

        phase = .uploading
        errorMessage = nil
        uploadProgress = "Packaging images…"

        do {
            let zipURL = try await ImageExportService.createZip(from: dir)
            uploadProgress = "Uploading…"

            let plyData = try await GaussianSplatCloudService.trainAndDownload(
                zipURL: zipURL,
                serverBaseURL: serverURL,
                pollInterval: 4.0
            ) { progress, message in
                Task { @MainActor in
                    if let p = progress {
                        uploadProgress = "Training… \(p)%"
                    } else if let m = message, !m.isEmpty {
                        uploadProgress = m
                    }
                }
            }

            let filename = "room_3dgs_\(Int(Date().timeIntervalSince1970)).ply"
            let plyURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            try plyData.write(to: plyURL, options: .atomic)
            resultPlyURL = plyURL
            phase = .done
        } catch {
            errorMessage = error.localizedDescription
            phase = .capture
        }
    }
}

// MARK: - Camera capture

private struct RoomFrameCameraView: UIViewControllerRepresentable {
    let framesDirectory: URL
    let captureTrigger: Int
    let onFrameSaved: () -> Void

    func makeUIViewController(context: Context) -> RoomFrameCameraViewController {
        let vc = RoomFrameCameraViewController()
        vc.framesDirectory = framesDirectory
        vc.onFrameSaved = onFrameSaved
        return vc
    }

    func updateUIViewController(_ uiViewController: RoomFrameCameraViewController, context: Context) {
        if context.coordinator.lastTrigger != captureTrigger {
            context.coordinator.lastTrigger = captureTrigger
            uiViewController.capturePhoto()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastTrigger = 0
    }
}

private final class RoomFrameCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var framesDirectory: URL?
    var onFrameSaved: (() -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false
    private var frameIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !isConfigured else { return }
        configureSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.startSession() }
                }
            }
        default:
            break
        }
    }

    private func startSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
        isConfigured = true
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(.auto) {
            settings.flashMode = .auto
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let dir = framesDirectory else { return }

        frameIndex += 1
        let name = String(format: "frame_%04d.jpg", frameIndex)
        let url = dir.appendingPathComponent(name)
        try? data.write(to: url, options: .atomic)
        DispatchQueue.main.async { [weak self] in
            self?.onFrameSaved?()
        }
    }
}

#Preview {
    NavigationStack {
        Room3DGSCaptureView()
    }
    .preferredColorScheme(.dark)
}
