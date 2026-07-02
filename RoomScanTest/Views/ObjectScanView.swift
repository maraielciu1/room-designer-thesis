//
//  ObjectScanView.swift
//  RoomScanTest
//
//  Guides the user through scanning a real-world object with Apple's
//  Object Capture API (iOS 17+), reconstructs a USDZ model on-device,
//  and saves it to the user's personal furniture library.
//
//  IMPORTANT - ObjectCaptureView's built-in buttons (Continue, Start
//  Capture, Done) are unreliable when presented inside .fullScreenCover.
//  We provide our OWN buttons for every session-state transition.
//

import SwiftUI
import RealityKit

// MARK: - ObjectScanView

struct ObjectScanView: View {
    @EnvironmentObject var scannedFurnitureManager: ScannedFurnitureManager

    var onDismiss: () -> Void

    // MARK: State machine

    enum Phase: Equatable {
        case intro
        case capturing
        case reconstructing
        case naming
        case done
        case unsupported
    }

    @State private var phase: Phase = .intro

    // Capture session
    @State private var captureSession: ObjectCaptureSession?
    @State private var imagesDirectory: URL?
    @State private var checkpointDirectory: URL?

    /// Tracks the session's current state as a simple string for UI switching.
    /// **Set to "Ready" in startCapture() BEFORE phase changes**, so the
    /// capture UI always has something to show from the very first frame.
    @State private var sessionState: String = "Ready"
    @State private var numberOfShotsTaken: Int = 0

    // Reconstruction
    @State private var reconstructionProgress: Double = 0
    @State private var generatedModelURL: URL?

    // Naming
    @State private var furnitureName = ""
    @State private var selectedCategory: FurnitureCategory = .other

    // Image export for Gaussian Splatting
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var showGSGuide = false

    // Cloud training (upload zip -> server runs 3DGS -> download .ply)
    @State private var lastAddedFurniture: ScannedFurniture?
    @State private var isCloudTraining = false
    @State private var cloudStatusMessage: String?
    @State private var cloudError: String?
    @AppStorage(GaussianSplatCloudConfig.serverBaseURLKey) private var cloudServerBaseURL: String = ""

    // Errors
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        if phase == .capturing, let session = captureSession {
            //  CAPTURING - camera feed + our custom controls
            ZStack {
                // Layer 1 - Apple's camera + visual guides
                ObjectCaptureView(session: session)
                    .ignoresSafeArea()

                // Layer 2 - Our buttons (transparent background lets camera show)
                VStack(spacing: 0) {
                    //  Top bar: Cancel + State badge
                    HStack(alignment: .top) {
                        Button(action: { cleanupAndReset() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "xmark")
                                Text("Cancel")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }

                        Spacer()

                        // State badge + shot counter
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(stateColor)
                                    .frame(width: 8, height: 8)
                                Text(sessionState)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())

                            if sessionState.contains("Capturing") {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 10))
                                    Text("\(numberOfShotsTaken) shots")
                                        .font(.caption2.weight(.semibold))
                                }
                                .foregroundColor(numberOfShotsTaken >= 20 ? .green : .yellow)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 16)

                    //  Instructions - pinned just below the top bar 
                    Text(currentInstructions)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 12)
                        .padding(.horizontal, 24)

                    Spacer()

                    //  Bottom: Action button only 
                    if !sessionState.contains("Finishing") &&
                       !sessionState.contains("Completed") {
                        Button(action: { handlePrimaryAction(session) }) {
                            Text(primaryButtonTitle)
                                .font(.headline)
                                .foregroundStyle(
                                    sessionState.contains("Capturing")
                                    ? AppTheme.primaryText
                                    : AppTheme.primaryDark
                                )
                                .frame(width: 220, height: 52)
                                .background(primaryButtonColor)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.primaryDark.opacity(0.35), radius: 4, y: 2)
                        }
                        .padding(.bottom, 50)
                    } else {
                        // Finishing spinner
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.3)
                            .padding(8)
                            .padding(.bottom, 50)
                    }
                }
                // Let touch pass through the Spacer to ObjectCaptureView
                .allowsHitTesting(true)
            }
            .task {
                await monitorCaptureState(session)
            }
            .task {
                await monitorFeedback(session)
            }
            .task {
                await monitorShotCount(session)
            }
            .alert("Scan Issue", isPresented: $showError) {
                Button("Try Again") { cleanupAndReset(); startCapture() }
                Button("OK", role: .cancel) { cleanupAndReset() }
            } message: {
                Text(errorMessage)
            }

        } else {
            //  ALL OTHER PHASES
            nonCaptureContent
                .alert("Scan Issue", isPresented: $showError) {
                    Button("Try Again") {
                        cleanupAndReset()
                        startCapture()
                    }
                    Button("OK", role: .cancel) {
                        if phase == .reconstructing { cleanupAndReset() }
                    }
                } message: {
                    Text(errorMessage)
                }
                .onAppear {
                    if !ObjectCaptureSession.isSupported {
                        phase = .unsupported
                    }
                }
        }
    }

    // MARK: - Bottom-control helpers

    /// Instructions shown above the action button.
    private var currentInstructions: String {
        if sessionState.contains("Detecting") {
            return "Adjust the bounding box, then tap Start Capture"
        } else if sessionState.contains("Capturing") {
            if numberOfShotsTaken < 20 {
                return "Keep scanning… (\(numberOfShotsTaken)/20 minimum)\nSlowly walk around the object."
            } else {
                return "Good coverage! (\(numberOfShotsTaken) shots)\nTap Finish Scan when done, or keep scanning."
            }
        } else if sessionState.contains("Finishing") {
            return "Processing capture…"
        } else {
            // Ready / Initializing / unknown
            return "Point the camera at your object, then tap Continue"
        }
    }

    /// Title of the primary action button.
    private var primaryButtonTitle: String {
        if sessionState.contains("Detecting") {
            return "Start Capture"
        } else if sessionState.contains("Capturing") {
            return "Finish Scan"
        } else {
            return "Continue"
        }
    }

    /// Colour of the primary action button.
    private var primaryButtonColor: Color {
        if sessionState.contains("Capturing") {
            return AppTheme.glowGreen
        } else {
            return AppTheme.warmAccent
        }
    }

    /// Colour of the state badge dot.
    private var stateColor: Color {
        if sessionState.contains("Ready")      { return .yellow }
        if sessionState.contains("Detecting")  { return .orange }
        if sessionState.contains("Capturing")  { return .green  }
        if sessionState.contains("Finishing")   { return .blue   }
        if sessionState.contains("Completed")   { return .green  }
        return .gray
    }

    /// Called when the user taps the primary button.
    private func handlePrimaryAction(_ session: ObjectCaptureSession) {
        if sessionState.contains("Capturing") {
            print("[ObjectScan] User tapped Finish Scan")
            session.finish()
        } else {
            // Ready or Detecting → start capturing images
            print("[ObjectScan] User tapped \(primaryButtonTitle)")
            session.startCapturing()
        }
    }

    // MARK: - Non-capture content

    @ViewBuilder
    private var nonCaptureContent: some View {
        switch phase {
        case .naming:
            namingView
        default:
            NavigationView {
                ZStack {
                    AppTheme.background.ignoresSafeArea()
                    Group {
                        switch phase {
                        case .unsupported:     unsupportedView
                        case .intro:           introView
                        case .reconstructing:  reconstructingView
                        case .done:            doneView
                        default:               EmptyView()
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .appNavigationChrome()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { onDismiss() }
                            .foregroundStyle(AppTheme.warmAccent)
                    }
                }
            }
        }
    }

    // MARK: - Phase Views

    private var unsupportedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.glowOrange)
            Text("Object Scanning Not Available")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(AppTheme.primaryText)
            Text("This feature requires an iPhone or iPad with a LiDAR scanner (iPhone 12 Pro or newer).")
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Go Back") { onDismiss() }
                .buttonStyle(GradientButtonStyle())
        }
    }

    private var introView: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "cube.transparent")
                .font(.system(size: 70))
                .foregroundStyle(AppTheme.accentGradientInline)

            Text("Scan an Object")
                .font(.title).fontWeight(.bold)
                .foregroundStyle(AppTheme.primaryText)

            Text("Walk around the object to create a 3D model you can place in any room.")
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 14) {
                instructionRow(icon: "1.circle.fill",
                               text: "Place object on a flat, contrasting surface")
                instructionRow(icon: "2.circle.fill",
                               text: "Tap 'Start Scanning' below")
                instructionRow(icon: "3.circle.fill",
                               text: "Point camera at the object & tap 'Continue'")
                instructionRow(icon: "4.circle.fill",
                               text: "Slowly walk around until fully captured")
                instructionRow(icon: "5.circle.fill",
                               text: "Tap 'Finish Scan' when done")
            }
            .padding()
            .appPanel(cornerRadius: AppTheme.cardCornerRadius)

            VStack(alignment: .leading, spacing: 8) {
                Label("Good lighting helps a lot",
                      systemImage: "sun.max.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Label("Textured / patterned objects scan best",
                      systemImage: "paintpalette.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Label("Avoid shiny, reflective, or transparent objects",
                      systemImage: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal)

            Spacer()

            Button(action: startCapture) {
                Label("Start Scanning", systemImage: "camera.fill")
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .padding()
    }

    private var reconstructingView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.warmAccent)
                .symbolEffect(.rotate)

            Text("Building 3D Model…")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(AppTheme.primaryText)

            ProgressView(value: reconstructionProgress)
                .progressViewStyle(.linear)
                .tint(AppTheme.warmAccent)
                .frame(width: 220)

            Text("\(Int(reconstructionProgress * 100))%")
                .font(.headline)
                .foregroundStyle(AppTheme.secondaryText)

            Text("This may take a few minutes.\nPlease keep the app open.")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    private var namingView: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                Form {
                Section {
                    TextField("Object Name", text: $furnitureName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    Text("e.g. \"Living Room Armchair\", \"IKEA Coffee Table\"")
                }

                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(FurnitureCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                } header: {
                    Text("Category")
                } footer: {
                    Text("Helps suggest this object for the right replacements")
                }

                Section {
                    Button(action: saveScannedFurniture) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save to My Furniture")
                        }
                        .font(.headline)
                    }
                    .disabled(furnitureName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Name Your Object")
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Discard") {
                        cleanupAndReset()
                        onDismiss()
                    }
                    .foregroundStyle(AppTheme.warmAccent)
                }
            }
        }
    }

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(AppTheme.glowGreen)

            Text("Object Saved!")
                .font(.title).fontWeight(.bold)
                .foregroundStyle(AppTheme.primaryText)

            Text("\"\(furnitureName)\" has been added to your furniture library.")
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

//            //  Gaussian Splatting export option 
//            VStack(spacing: 12) {
//                Divider()
//                    .background(AppTheme.warmAccent.opacity(0.25))
//                    .padding(.horizontal, 40)
//
//                Text("Gaussian Splatting")
//                    .font(.subheadline.weight(.semibold))
//                    .foregroundStyle(AppTheme.primaryText)
//
//                Text("Export the captured images to train a Gaussian Splat model for comparison with Object Capture.")
//                    .font(.caption)
//                    .foregroundStyle(AppTheme.secondaryText)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 40)
//
//                if isExporting {
//                    ProgressView("Packaging images…")
//                        .font(.caption)
//                        .tint(AppTheme.warmAccent)
//                } else {
//                    Button(action: exportImagesForGS) {
//                        Label("Export Images for 3DGS Training", systemImage: "photo.stack")
//                    }
//                    .buttonStyle(SecondaryChipButtonStyle())
//                    .padding(.horizontal, 24)
//                }
//
//                //  Train in Cloud (server runs 3DGS, then app downloads .ply) 
////                VStack(alignment: .leading, spacing: 6) {
////                    Text("Server URL (your backend that runs 3DGS)")
////                        .font(.caption2)
////                        .foregroundStyle(AppTheme.secondaryText)
////                    TextField("https://your-server.com/gs", text: $cloudServerBaseURL)
////                        .textFieldStyle(.plain)
////                        .textInputAutocapitalization(.never)
////                        .autocorrectionDisabled()
////                        .font(.caption)
////                        .foregroundStyle(AppTheme.primaryText)
////                        .padding(12)
////                        .background(AppTheme.secondaryTint.opacity(0.35))
////                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
////                        .overlay(
////                            RoundedRectangle(cornerRadius: 10, style: .continuous)
////                                .strokeBorder(AppTheme.warmAccent.opacity(0.25), lineWidth: 1)
////                        )
////                }
////                .padding(.horizontal, 24)
//
//                if isCloudTraining {
//                    VStack(spacing: 4) {
//                        ProgressView()
//                            .tint(AppTheme.warmAccent)
//                        Text(cloudStatusMessage ?? "Training…")
//                            .font(.caption)
//                            .foregroundStyle(AppTheme.secondaryText)
//                    }
//                } else {
//                    if let err = cloudError {
//                        Text(err)
//                            .font(.caption)
//                            .foregroundStyle(AppTheme.glowRed)
//                            .multilineTextAlignment(.center)
//                        Text("Tap below to try again.")
//                            .font(.caption2)
//                            .foregroundStyle(AppTheme.tertiaryText)
//                    }
//                    Button(action: startCloudTraining) {
//                        Label("Train in Cloud", systemImage: "cloud.fill")
//                    }
//                    .buttonStyle(SecondaryChipButtonStyle())
//                    .padding(.horizontal, 24)
//                    .disabled(cloudServerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lastAddedFurniture == nil)
//                    .opacity(cloudServerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
//                }
//
//                Button(action: { showGSGuide = true }) {
//                    Label("How to Train a Gaussian Splat", systemImage: "questionmark.circle")
//                        .font(.caption.weight(.medium))
//                        .foregroundStyle(AppTheme.tertiaryText)
//                }
//            }
//            .padding(.top, 8)
//            .appPanel(cornerRadius: AppTheme.cardCornerRadius)
//            .padding(.horizontal, 16)

            Spacer()

            Button("Done") {
                scannedFurnitureManager.cleanupSessionFiles()
                onDismiss()
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .sheet(isPresented: $showGSGuide) {
            GaussianSplattingGuideView()
                .appSheetBackground()
        }
    }

    // MARK: - Helpers

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.warmAccent)
                .font(.title3)
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    // MARK: - Capture lifecycle

    private func startCapture() {
        do {
            let dirs = try scannedFurnitureManager.createSessionDirectories()
            imagesDirectory = dirs.images
            checkpointDirectory = dirs.checkpoint

            print("[ObjectScan] Images dir: \(dirs.images.path)")
            print("[ObjectScan] Checkpoint dir: \(dirs.checkpoint.path)")

            let session = ObjectCaptureSession()
            var config = ObjectCaptureSession.Configuration()
            config.checkpointDirectory = dirs.checkpoint
            config.isOverCaptureEnabled = true
            session.start(imagesDirectory: dirs.images, configuration: config)

            print("[ObjectScan] Session started")

            
            //   CRITICAL: set sessionState BEFORE changing phase.
            //   If we leave it empty, the bottom controls show
            //   EmptyView because the .task that monitors state
            //   starts AFTER the view appears and misses the
            //   initial .ready event from the AsyncStream.
            captureSession = session
            sessionState = "Ready"
            phase = .capturing

        } catch {
            errorMessage = "Could not set up scanning: \(error.localizedDescription)"
            showError = true
            print("[ObjectScan] ERROR starting capture: \(error)")
        }
    }

    /// Monitors the session's state AsyncStream and updates `sessionState`.
    /// Uses `@MainActor` to ensure all @State writes happen on the main thread.
    private func monitorCaptureState(_ session: ObjectCaptureSession) async {
        print("[ObjectScan] Monitoring session state updates…")
        for await state in session.stateUpdates {
            print("[ObjectScan] State -> \(state)")
            await MainActor.run {
                switch state {
                case .initializing:
                    sessionState = "Initializing…"
                case .ready:
                    sessionState = "Ready"
                    print("[ObjectScan] Ready - point camera at object, tap Continue")
                case .detecting:
                    sessionState = "Detecting"
                    print("[ObjectScan] Detecting - position the bounding box")
                case .capturing:
                    sessionState = "Capturing"
                    numberOfShotsTaken = 0
                    print("[ObjectScan] Capturing - walk around the object")
                case .finishing:
                    sessionState = "Finishing…"
                case .completed:
                    sessionState = "Completed"
                    print("[ObjectScan] Completed - starting reconstruction")
                    phase = .reconstructing
                    // Start reconstruction outside MainActor.run (it's async)
                    Task { await startReconstruction() }
                case .failed(let error):
                    print("[ObjectScan] FAILED: \(error)")
                    errorMessage = "Scan failed: \(error.localizedDescription)"
                    showError = true
                @unknown default:
                    print("[ObjectScan] Unknown state: \(state)")
                    break
                }
            }
        }
    }

    private func monitorFeedback(_ session: ObjectCaptureSession) async {
        for await feedback in session.feedbackUpdates {
            print("[ObjectScan] Feedback: \(feedback)")
        }
    }

    private func monitorShotCount(_ session: ObjectCaptureSession) async {
        while !Task.isCancelled {
            let count = session.numberOfShotsTaken
            await MainActor.run {
                if count != numberOfShotsTaken {
                    numberOfShotsTaken = count
                }
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    // MARK: - Reconstruction

    /// Count how many image files are in the given directory.
    private func countCapturedImages(in directory: URL) -> Int {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return 0 }
        let imageExtensions = Set(["heic", "heif", "jpg", "jpeg", "png"])
        return contents.filter { imageExtensions.contains($0.pathExtension.lowercased()) }.count
    }

    private func startReconstruction() async {
        guard let imagesDir = imagesDirectory else {
            await MainActor.run {
                errorMessage = "Images directory missing."
                showError = true
            }
            return
        }

        //  Validate that we have enough captured images 
        let imageCount = countCapturedImages(in: imagesDir)
        print("[ObjectScan] Found \(imageCount) captured images in \(imagesDir.lastPathComponent)")

        if imageCount < 20 {
            await MainActor.run {
                errorMessage = """
                Not enough scan data (\(imageCount) images captured).

                For a successful 3D reconstruction you need at least 20-30 overlapping photos. Tips:
                • Walk slowly around the entire object
                • Cover all sides (front, back, top)
                • Keep the object centered in the frame
                • Ensure good, even lighting
                """
                showError = true
                phase = .intro
            }
            return
        }

        let outputFileName = UUID().uuidString + ".usdz"
        let outputURL = scannedFurnitureManager.modelDirectory()
            .appendingPathComponent(outputFileName)
        await MainActor.run { generatedModelURL = outputURL }

        print("[ObjectScan] Starting reconstruction (\(imageCount) images) → \(outputURL.lastPathComponent)")

        do {
            //  Configure session with checkpoint + sequential ordering
            var configuration = PhotogrammetrySession.Configuration()
            configuration.sampleOrdering = .sequential
            configuration.featureSensitivity = .normal
            configuration.isObjectMaskingEnabled = true
            if let checkpointDir = checkpointDirectory {
                configuration.checkpointDirectory = checkpointDir
            }

            let pgSession = try PhotogrammetrySession(
                input: imagesDir,
                configuration: configuration
            )

            try pgSession.process(requests: [
                .modelFile(url: outputURL, detail: .reduced)
            ])

            for try await output in pgSession.outputs {
                switch output {
                case .processingComplete:
                    print("[ObjectScan] Reconstruction complete!")
                    await MainActor.run { phase = .naming }
                case .requestProgress(_, let fraction):
                    await MainActor.run { reconstructionProgress = fraction }
                case .requestError(_, let error):
                    throw error
                default:
                    break
                }
            }
        } catch {
            print("[ObjectScan] Reconstruction FAILED: \(error)")
            let friendlyMessage = reconstructionErrorMessage(from: error, imageCount: imageCount)
            await MainActor.run {
                errorMessage = friendlyMessage
                showError = true
                phase = .intro
            }
        }
    }

    /// Produce a user-friendly error message based on the reconstruction error.
    private func reconstructionErrorMessage(from error: Error, imageCount: Int) -> String {
        let errorDesc = "\(error)"

        // Insufficient data / content
        if errorDesc.contains("error 6") || errorDesc.contains("error 5") ||
           errorDesc.lowercased().contains("insufficient") {
            return """
            Not enough detail to build a 3D model (\(imageCount) images captured).

            Try again with these tips:
            • Scan more slowly and from more angles
            • Walk a full circle (or two) around the object
            • Make sure the object has visible texture/pattern
            • Avoid shiny, reflective, or transparent surfaces
            • Use good, even lighting, avoid harsh shadows
            """
        }

        // Resource / memory limits
        if errorDesc.lowercased().contains("resource") || errorDesc.lowercased().contains("memory") {
            return """
            Your device ran out of resources during reconstruction.

            Try scanning a smaller object, or close other apps to free up memory.
            """
        }

        // Generic fallback
        return """
        3D reconstruction failed.

        This can happen when the scan doesn't have enough overlapping images or the object is too difficult to reconstruct. Please try scanning again with better coverage.

        (Technical detail: \(error.localizedDescription))
        """
    }

    // MARK: - Save

    private func saveScannedFurniture() {
        guard let modelURL = generatedModelURL else { return }

        lastAddedFurniture = scannedFurnitureManager.addFurniture(
            name: furnitureName.trimmingCharacters(in: .whitespaces),
            category: selectedCategory.rawValue,
            usdzURL: modelURL
        )

        // NOTE: Do NOT clean up session files here - the user may still want
        // to export the captured images for Gaussian Splatting training from
        // the "done" screen. Cleanup happens when the user taps "Done".
        phase = .done
    }

    private func cleanupAndReset() {
        captureSession?.cancel()
        captureSession = nil
        scannedFurnitureManager.cleanupSessionFiles()
        if let url = generatedModelURL {
            try? FileManager.default.removeItem(at: url)
        }
        generatedModelURL = nil
        reconstructionProgress = 0
        sessionState = "Ready"
        numberOfShotsTaken = 0
        phase = .intro
    }

    // MARK: - Gaussian Splatting Image Export

    private func exportImagesForGS() {
        guard let imagesDir = imagesDirectory else {
            errorMessage = "No images directory found. Images are only available right after scanning."
            showError = true
            return
        }

        let count = ImageExportService.imageCount(in: imagesDir)
        guard count > 0 else {
            errorMessage = "No captured images found in the session directory."
            showError = true
            return
        }

        isExporting = true

        Task {
            do {
                let zipURL = try await ImageExportService.createZip(from: imagesDir)
                await MainActor.run {
                    isExporting = false
                    exportURL = zipURL
                    // Present share sheet
                    ImageExportService.share(fileURL: zipURL)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = "Failed to export images: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    // MARK: - Cloud Training (server runs 3DGS, app downloads .ply)

    private func startCloudTraining() {
        guard let imagesDir = imagesDirectory else {
            cloudError = "Images no longer available. Export or train right after saving."
            return
        }
        guard let item = lastAddedFurniture else {
            cloudError = "No object to attach the splat to."
            return
        }
        let base = cloudServerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, let serverURL = URL(string: base.hasSuffix("/") ? String(base.dropLast()) : base) else {
            cloudError = "Enter a valid server URL (e.g. https://your-server.com/gs)."
            return
        }
        let count = ImageExportService.imageCount(in: imagesDir)
        guard count >= 20 else {
            cloudError = "Need at least 20 images. You have \(count)."
            return
        }

        cloudError = nil
        isCloudTraining = true
        cloudStatusMessage = "Packaging images…"

        Task {
            do {
                let zipURL = try await ImageExportService.createZip(from: imagesDir)
                await MainActor.run { cloudStatusMessage = "Uploading…" }

                let plyData = try await GaussianSplatCloudService.trainAndDownload(
                    zipURL: zipURL,
                    serverBaseURL: serverURL,
                    pollInterval: 4.0
                ) { progress, message in
                    Task { @MainActor in
                        if let p = progress {
                            cloudStatusMessage = "Training… \(p)%"
                        } else if let m = message, !m.isEmpty {
                            cloudStatusMessage = m
                        } else {
                            cloudStatusMessage = "Training…"
                        }
                    }
                }

                await MainActor.run {
                    let splatName = "\(item.id.uuidString)_splat.ply"
                    let splatURL = scannedFurnitureManager.modelDirectory().appendingPathComponent(splatName)
                    do {
                        try plyData.write(to: splatURL)
                        let fileSize = Int64(plyData.count)
                        var gaussianCount: Int?
                        if let scene = try? PLYParser.parse(data: plyData) {
                            gaussianCount = scene.gaussians.count
                        }
                        scannedFurnitureManager.attachSplat(
                            to: item,
                            splatFileName: splatName,
                            gaussianCount: gaussianCount,
                            fileSizeBytes: fileSize
                        )
                        cloudStatusMessage = "Done! Splat attached to \"\(item.name)\"."
                        cloudError = nil
                    } catch {
                        cloudError = "Could not save .ply: \(error.localizedDescription)"
                    }
                    isCloudTraining = false
                }
            } catch {
                await MainActor.run {
                    isCloudTraining = false
                    let msg = error.localizedDescription
                    if msg.lowercased().contains("offline") || msg.lowercased().contains("internet") {
                        cloudError = "Can’t reach the server. Check: (1) iPhone and Mac on same Wi‑Fi, (2) Server URL is correct (e.g. http://192.168.1.206:5001), (3) Allow \"Local Network\" when the app prompts, or enable it in Settings -> Privacy & Security -> Local Network."
                    } else {
                        cloudError = msg
                    }
                }
            }
        }
    }
}
