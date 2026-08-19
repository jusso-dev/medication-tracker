import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import VisionKit

struct MedicationScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let title: String
    let onUse: (MedicationScanResult) -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var result: MedicationScanResult?
    @State private var isProcessing = false
    @State private var showingCamera = false
    @State private var cameraDenied = false
    @State private var errorMessage: String?
    @State private var activeScanID: UUID?
    @AccessibilityFocusState private var resultHeadingIsFocused: Bool

    private let ocrService = MedicationOCRService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Label(
                        "Scan the printed label or prescription",
                        systemImage: "viewfinder"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.title)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Text recognition stays on this device. Always review the detected details against the original label before saving.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    captureActions

                    if isProcessing {
                        ProgressView("Reading text…")
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if let result {
                        resultCard(result)
                    } else {
                        ContentUnavailableView(
                            "Ready to scan",
                            systemImage: "text.viewfinder",
                            description: Text("Use the camera or choose a clear photo of the printed text.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("scan.close")
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            DocumentScannerView(
                onComplete: { pages in
                    showingCamera = false
                    process(pages)
                },
                onCancel: {
                    showingCamera = false
                },
                onError: { message in
                    showingCamera = false
                    errorMessage = message
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            selectedPhoto = nil
            let requestID = UUID()
            activeScanID = requestID
            isProcessing = true
            result = nil
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        guard activeScanID == requestID else { return }
                        isProcessing = false
                        errorMessage = "The selected photo could not be loaded."
                        return
                    }
                    guard activeScanID == requestID else { return }
                    process([data], requestID: requestID)
                } catch {
                    guard activeScanID == requestID else { return }
                    isProcessing = false
                    errorMessage = "The selected photo could not be loaded."
                }
            }
        }
        .alert("Camera access needed", isPresented: $cameraDenied) {
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow camera access in iOS Settings, or choose a photo instead.")
        }
        .alert("Scan failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var captureActions: some View {
        ViewThatFits {
            HStack(spacing: 12) {
                cameraButton
                photoButton
            }
            VStack(spacing: 12) {
                cameraButton
                photoButton
            }
        }
    }

    @ViewBuilder
    private var cameraButton: some View {
        if VNDocumentCameraViewController.isSupported {
            Button {
                requestCamera()
            } label: {
                Label("Scan with Camera", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppTheme.blue)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private var photoButton: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            Label("Choose Photo", systemImage: "photo")
                .font(.headline)
                .foregroundStyle(AppTheme.blue)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(AppTheme.blueFill)
                .clipShape(.capsule)
        }
    }

    private func resultCard(_ result: MedicationScanResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Detected details")
                .accessibilityFocused($resultHeadingIsFocused)

            detectedRow("Medicine", value: result.medicineName)
            if let amount = result.amount, let unit = result.unit {
                detectedRow(
                    "Strength",
                    value: "\(amount.medicationFormatted) \(unit.displayName)"
                )
            }
            detectedRow("Expiry", value: result.expiryDate?.longMedicationDate)
            detectedRow(
                "Repeats remaining",
                value: result.repeatsRemaining.map(String.init)
            )
            detectedRow(
                "Repeats authorised",
                value: result.repeatsAuthorised.map(String.init)
            )
            detectedRow("Script number", value: result.scriptNumber)
            detectedRow("Prescriber", value: result.prescriber)

            Text("Recognition confidence: \(Int(result.confidence * 100))%")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            DisclosureGroup("Recognised text") {
                Text(result.rawText.isEmpty ? "No text detected" : result.rawText)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }

            Button {
                onUse(result)
                dismiss()
            } label: {
                Label("Use scanned details", systemImage: "checkmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppTheme.blue)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(result.rawText.isEmpty)
        }
        .medicationCard()
    }

    @ViewBuilder
    private func detectedRow(_ label: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(label, value: value)
                .foregroundStyle(AppTheme.text)
        }
    }

    private func requestCamera() {
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                showingCamera = true
            case .notDetermined:
                showingCamera = await AVCaptureDevice.requestAccess(for: .video)
                cameraDenied = !showingCamera
            case .denied, .restricted:
                cameraDenied = true
            @unknown default:
                cameraDenied = true
            }
        }
    }

    private func process(_ pages: [Data], requestID: UUID? = nil) {
        guard !pages.isEmpty else {
            errorMessage = "No image was captured."
            return
        }
        let requestID = requestID ?? UUID()
        activeScanID = requestID
        isProcessing = true
        result = nil
        resultHeadingIsFocused = false
        Task {
            do {
                let scanned = try await ocrService.scan(imageData: pages)
                guard activeScanID == requestID else { return }
                guard !scanned.rawText.isEmpty else {
                    isProcessing = false
                    errorMessage = "No readable text was found. Try a clearer, well-lit image."
                    return
                }
                result = scanned
                isProcessing = false
                await Task.yield()
                resultHeadingIsFocused = true
            } catch {
                guard activeScanID == requestID else { return }
                isProcessing = false
                errorMessage = "The text could not be recognised. Try another image."
            }
        }
    }
}
