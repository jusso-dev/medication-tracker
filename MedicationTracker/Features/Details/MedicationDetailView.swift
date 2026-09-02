import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct MedicationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager

    let medicine: Medicine
    var isReadOnly = false
    var onRestart: (() -> Void)?

    @State private var showingEdit = false
    @State private var showingScriptEditor = false
    @State private var selectedScript: RefillScript?
    @State private var pendingAction: MedicationDetailAction?
    @State private var selectedImage: PhotosPickerItem?
    @State private var isSavingImage = false
    @State private var imageErrorMessage: String?
    @State private var showingImageViewer = false

    var body: some View {
        VStack(spacing: 0) {
            SheetTitleBar(
                title: "Medication",
                onClose: { dismiss() },
                onEdit: isReadOnly ? nil : { showingEdit = true }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    medicationImageSection

                    dailyIntake

                    if !medicine.asNeeded {
                        weeklySchedule
                    }

                    duration

                    if let expiryDate = medicine.packageExpiryDate {
                        packageExpiry(expiryDate)
                    }

                    if let quantity = medicine.quantityRemaining {
                        quantityRemaining(quantity)
                    }

                    refillScripts

                    if isReadOnly, let onRestart {
                        FooterActionButton(
                            title: "Restart",
                            symbol: "arrow.clockwise",
                            foreground: .white,
                            background: AppTheme.blue,
                            action: onRestart
                        )
                    } else if !isReadOnly {
                        footer
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showingEdit) {
            MedicineWizardView(medicine: medicine)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingScriptEditor) {
            RefillScriptEditorView(medicine: medicine)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedScript) { script in
            RefillScriptReviewView(script: script, allowsEditing: !isReadOnly)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $showingImageViewer) {
            if let imageData = medicine.scannedImageData,
               let image = UIImage(data: imageData) {
                MedicationImageViewer(image: image, imageData: imageData)
            }
        }
        .onChange(of: selectedImage) { _, item in
            guard let item else { return }
            importImage(item)
        }
        .alert(item: $pendingAction) { action in
            switch action {
            case .delete:
                Alert(
                    title: Text("Delete \(medicine.name)?"),
                    message: Text("This cannot be undone"),
                    primaryButton: .destructive(Text("Delete"), action: deleteMedicine),
                    secondaryButton: .cancel()
                )
            case .complete:
                Alert(
                    title: Text("Complete \(medicine.name)?"),
                    message: Text("This moves it to history"),
                    primaryButton: .default(Text("Complete"), action: completeMedicine),
                    secondaryButton: .cancel()
                )
            case .removeImage:
                Alert(
                    title: Text("Remove medication image?"),
                    message: Text("The medication record will remain unchanged."),
                    primaryButton: .destructive(
                        Text("Remove"),
                        action: removeMedicationImage
                    ),
                    secondaryButton: .cancel()
                )
            }
        }
        .alert("Image update failed", isPresented: Binding(
            get: { imageErrorMessage != nil },
            set: { if !$0 { imageErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(imageErrorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(medicine.name)
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.title)
            Text(medicine.strengthText)
                .font(.title3)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var dailyIntake: some View {
        DetailLabelRow("Daily intake", symbol: "pill") {
            VStack(alignment: .leading, spacing: 8) {
                if medicine.asNeeded {
                    Text("As needed")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.blueFill)
                        .clipShape(.capsule)
                } else {
                    ForEach(medicine.sortedTimes, id: \.self) { minutes in
                        Text(minutes.medicationTime)
                            .font(.headline)
                    }
                }

                if let notes = medicine.notes {
                    Divider()
                    Label(notes, systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private var weeklySchedule: some View {
        DetailLabelRow("Weekly schedule", symbol: "calendar") {
            DayCircles(selectedDays: Set(medicine.daysOfWeek))
        }
    }

    private var duration: some View {
        DetailLabelRow("Duration", symbol: "hourglass") {
            VStack(alignment: .leading, spacing: 10) {
                Label(medicine.startDate.shortMedicationDate, systemImage: "play.fill")
                if let endDate = medicine.endDate {
                    Label(endDate.shortMedicationDate, systemImage: "stop.fill")
                } else {
                    Label("Ongoing — no end date", systemImage: "infinity")
                }
            }
            .font(.headline)
        }
    }

    @ViewBuilder
    private var medicationImageSection: some View {
        if let imageData = medicine.scannedImageData,
           let image = UIImage(data: imageData) {
            medicationImageCard(image)
        } else {
            DetailLabelRow("Medication image", symbol: "photo") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add a photo of the medication or its packaging for future reference.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    addImagePicker
                    imageSavingIndicator
                }
            }
        }
    }

    private func medicationImageCard(_ image: UIImage) -> some View {
        DetailLabelRow("Medication image", symbol: "photo") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showingImageViewer = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
                        .accessibilityIdentifier("medication.image")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View medication image full screen")
                .accessibilityHint("Opens zoom and save controls")
                .accessibilityIdentifier("medication.image.open")
                Text("Tap to view full screen, zoom, or save to Photos.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)

                ViewThatFits {
                    HStack(spacing: 10) {
                        replaceImagePicker
                        removeImageButton
                    }
                    VStack(spacing: 10) {
                        replaceImagePicker
                        removeImageButton
                    }
                }
                imageSavingIndicator
            }
        }
    }

    private var addImagePicker: some View {
        PhotosPicker(selection: $selectedImage, matching: .images) {
            Label("Add image", systemImage: "photo.badge.plus")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppTheme.blue)
                .clipShape(.capsule)
        }
        .disabled(isSavingImage)
        .accessibilityIdentifier("medication.image.add")
    }

    private var replaceImagePicker: some View {
        PhotosPicker(selection: $selectedImage, matching: .images) {
            Label("Replace image", systemImage: "photo.on.rectangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppTheme.blueFill)
                .clipShape(.capsule)
        }
        .disabled(isSavingImage)
        .accessibilityIdentifier("medication.image.replace")
    }

    private var removeImageButton: some View {
        Button {
            pendingAction = .removeImage
        } label: {
            Label("Remove image", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.red)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppTheme.redFill)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(isSavingImage)
        .accessibilityIdentifier("medication.image.remove")
    }

    @ViewBuilder
    private var imageSavingIndicator: some View {
        if isSavingImage {
            ProgressView("Saving image…")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func packageExpiry(_ date: Date) -> some View {
        DetailLabelRow("Package expiry", symbol: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 5) {
                Text(date.longMedicationDate)
                    .font(.headline)
                if date.startOfDay < Date.now.startOfDay {
                    Label("Expired", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.red)
                }
            }
        }
    }

    private var refillScripts: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Refill Scripts")

            if sortedScripts.isEmpty {
                Text("No refill scripts recorded")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .medicationCard()
            } else {
                ForEach(sortedScripts) { script in
                    Button {
                        selectedScript = script
                    } label: {
                        HStack(spacing: 12) {
                            CircularSymbol(
                                name: script.status == .valid
                                    ? "checkmark.seal"
                                    : "doc.text.magnifyingglass"
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(script.status.title)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.title)
                                Text("\(script.repeatsRemaining) repeats remaining")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                if let expiryDate = script.expiryDate {
                                    Text("Expires \(expiryDate.shortMedicationDate)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.blue)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .medicationCard()
                    .accessibilityHint("Opens refill script review")
                    .accessibilityIdentifier(
                        "refill.script.\(script.scriptNumber ?? script.id.uuidString)"
                    )
                }
            }

            if !isReadOnly {
                Button {
                    showingScriptEditor = true
                } label: {
                    Label("Add refill script", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .foregroundStyle(AppTheme.blue)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(AppTheme.blueFill)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("refill.add")
            }
        }
    }

    private var sortedScripts: [RefillScript] {
        medicine.refillScripts.sorted {
            ($0.expiryDate ?? .distantPast) > ($1.expiryDate ?? .distantPast)
        }
    }

    private func quantityRemaining(_ quantity: Decimal) -> some View {
        DetailLabelRow("Quantity remaining", symbol: "shippingbox") {
            VStack(alignment: .leading, spacing: 5) {
                Text(quantity.medicationFormatted)
                    .font(.title3.bold())
                if let refillAt = medicine.refillAt {
                    Text("Running low at \(refillAt.medicationFormatted)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            FooterActionButton(
                title: "Delete",
                symbol: "trash",
                foreground: AppTheme.red,
                background: AppTheme.redFill
            ) {
                pendingAction = .delete
            }
            FooterActionButton(
                title: "Complete",
                symbol: "checkmark",
                foreground: AppTheme.green,
                background: AppTheme.greenFill
            ) {
                pendingAction = .complete
            }
        }
    }

    private func deleteMedicine() {
        let medicineID = medicine.id
        let plan = medicine.plan
        modelContext.delete(medicine)
        plan?.updateDates()
        try? modelContext.save()
        Task {
            await notificationManager.removeNotifications(forMedicineID: medicineID)
        }
        dismiss()
    }

    private func completeMedicine() {
        medicine.status = .completed
        medicine.completedAt = .now
        medicine.endDate = Date.now.startOfDay
        medicine.plan?.updateDates()
        try? modelContext.save()
        Task {
            await notificationManager.removeNotifications(for: medicine)
            await notificationManager.rebuildAll(context: modelContext)
        }
        dismiss()
    }

    private func importImage(_ item: PhotosPickerItem) {
        selectedImage = nil
        isSavingImage = true

        Task {
            do {
                guard let originalData = try await item.loadTransferable(type: Data.self),
                      let storedData = await Task.detached(priority: .userInitiated, operation: {
                          MedicationOCRService.preparedStoredImage(from: originalData)
                      }).value else {
                    isSavingImage = false
                    imageErrorMessage = "The selected photo could not be loaded. Try another image."
                    return
                }

                let previousData = medicine.scannedImageData
                medicine.scannedImageData = storedData
                do {
                    try modelContext.save()
                } catch {
                    medicine.scannedImageData = previousData
                    throw error
                }
            } catch {
                imageErrorMessage = "The selected photo could not be saved. Try again."
            }
            isSavingImage = false
        }
    }

    private func removeMedicationImage() {
        let previousData = medicine.scannedImageData
        medicine.scannedImageData = nil
        do {
            try modelContext.save()
        } catch {
            medicine.scannedImageData = previousData
            imageErrorMessage = "The image could not be removed. Try again."
        }
    }
}

private enum MedicationDetailAction: String, Identifiable {
    case delete
    case complete
    case removeImage

    var id: String { rawValue }
}

private struct MedicationImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let image: UIImage
    let imageData: Data

    @State private var scale = 1.0
    @State private var offset = CGSize.zero
    @State private var isSaving = false
    @State private var didSave = false
    @State private var saveError: MedicationPhotoSaveError?
    @GestureState private var gestureScale = 1.0
    @GestureState private var dragOffset = CGSize.zero

    private let minimumScale = 1.0
    private let maximumScale = 5.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                imageView(in: proxy.size)

                VStack(spacing: 16) {
                    topBar
                    Spacer()
                    zoomControls(in: proxy.size)
                }
                .padding(16)
            }
            .alert(item: $saveError) { error in
                if error == .accessDenied {
                    return Alert(
                        title: Text("Photos access needed"),
                        message: Text(error.localizedDescription),
                        primaryButton: .default(Text("Open Settings"), action: openSettings),
                        secondaryButton: .cancel()
                    )
                }
                return Alert(
                    title: Text("Photo could not be saved"),
                    message: Text(error.localizedDescription),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: dismiss.callAsFunction) {
                Label("Close", systemImage: "xmark")
            }
            .accessibilityIdentifier("medication.image.viewer.close")

            Spacer()

            if didSave {
                Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("medication.image.save.status")
            } else {
                Button {
                    saveToPhotos()
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(isSaving)
                .accessibilityIdentifier("medication.image.save")
            }
        }
        .font(.headline)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(.ultraThinMaterial, in: .capsule)
    }

    private func imageView(in viewport: CGSize) -> some View {
        let visibleScale = clampedScale(scale * gestureScale)
        let visibleOffset = clampedOffset(
            CGSize(
                width: offset.width + dragOffset.width,
                height: offset.height + dragOffset.height
            ),
            in: viewport,
            at: visibleScale
        )

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: viewport.width, height: viewport.height)
            .scaleEffect(visibleScale)
            .offset(visibleOffset)
            .contentShape(.rect)
            .gesture(magnifyGesture(in: viewport))
            .simultaneousGesture(panGesture(in: viewport))
            .onTapGesture(count: 2) {
                if scale > minimumScale {
                    resetZoom()
                } else {
                    setScale(2, in: viewport)
                }
            }
            .accessibilityLabel("Medication image, full screen")
            .accessibilityValue("\(Int(visibleScale * 100)) percent zoom")
            .accessibilityZoomAction { action in
                switch action.direction {
                case .zoomIn:
                    adjustScale(by: 0.5, in: viewport)
                case .zoomOut:
                    adjustScale(by: -0.5, in: viewport)
                }
            }
            .accessibilityIdentifier("medication.image.fullscreen")
    }

    private func zoomControls(in viewport: CGSize) -> some View {
        VStack(spacing: 10) {
            Text("Pinch to zoom. Drag when zoomed. Double-tap to reset.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Button {
                    adjustScale(by: -0.5, in: viewport)
                } label: {
                    Label("Zoom out", systemImage: "minus.magnifyingglass")
                        .labelStyle(.iconOnly)
                }
                .disabled(scale <= minimumScale)
                .accessibilityLabel("Zoom out")
                .accessibilityIdentifier("medication.image.zoom.out")

                Button {
                    resetZoom()
                } label: {
                    Text("\(Int(scale * 100))%")
                        .monospacedDigit()
                        .frame(minWidth: 54)
                }
                .disabled(scale == minimumScale && offset == .zero)
                .accessibilityLabel("Reset zoom")
                .accessibilityValue("\(Int(scale * 100)) percent")
                .accessibilityIdentifier("medication.image.zoom.reset")

                Button {
                    adjustScale(by: 0.5, in: viewport)
                } label: {
                    Label("Zoom in", systemImage: "plus.magnifyingglass")
                        .labelStyle(.iconOnly)
                }
                .disabled(scale >= maximumScale)
                .accessibilityLabel("Zoom in")
                .accessibilityIdentifier("medication.image.zoom.in")
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .background(.ultraThinMaterial, in: .capsule)
        }
    }

    private func magnifyGesture(in viewport: CGSize) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .updating($gestureScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                setScale(scale * value.magnification, in: viewport)
            }
    }

    private func panGesture(in viewport: CGSize) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                guard scale > minimumScale else { return }
                state = value.translation
            }
            .onEnded { value in
                guard scale > minimumScale else { return }
                offset = clampedOffset(
                    CGSize(
                        width: offset.width + value.translation.width,
                        height: offset.height + value.translation.height
                    ),
                    in: viewport,
                    at: scale
                )
            }
    }

    private func adjustScale(by change: Double, in viewport: CGSize) {
        setScale(scale + change, in: viewport)
    }

    private func setScale(_ proposedScale: Double, in viewport: CGSize) {
        let newScale = clampedScale(proposedScale)
        withAnimation(.spring(duration: 0.25)) {
            scale = newScale
            offset = newScale == minimumScale
                ? .zero
                : clampedOffset(offset, in: viewport, at: newScale)
        }
    }

    private func resetZoom() {
        withAnimation(.spring(duration: 0.25)) {
            scale = minimumScale
            offset = .zero
        }
    }

    private func clampedScale(_ value: Double) -> Double {
        min(max(value, minimumScale), maximumScale)
    }

    private func clampedOffset(
        _ proposedOffset: CGSize,
        in viewport: CGSize,
        at scale: Double
    ) -> CGSize {
        guard scale > minimumScale else { return .zero }
        let fittedSize = fittedImageSize(in: viewport)
        let maximumX = max(0, (fittedSize.width * scale - viewport.width) / 2)
        let maximumY = max(0, (fittedSize.height * scale - viewport.height) / 2)
        return CGSize(
            width: min(max(proposedOffset.width, -maximumX), maximumX),
            height: min(max(proposedOffset.height, -maximumY), maximumY)
        )
    }

    private func fittedImageSize(in viewport: CGSize) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else { return viewport }
        let ratio = min(
            viewport.width / image.size.width,
            viewport.height / image.size.height
        )
        return CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
    }

    private func saveToPhotos() {
        isSaving = true
        Task {
            do {
                try await MedicationPhotoLibrary.save(imageData)
                didSave = true
            } catch let error as MedicationPhotoSaveError {
                saveError = error
            } catch {
                saveError = .saveFailed
            }
            isSaving = false
        }
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}

private enum MedicationPhotoLibrary {
    static func save(_ imageData: Data) async throws {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-photo-save") {
            return
        }
        #endif

        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let status = currentStatus == .notDetermined
            ? await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            : currentStatus
        guard status == .authorized || status == .limited else {
            throw MedicationPhotoSaveError.accessDenied
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: imageData, options: nil)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? MedicationPhotoSaveError.saveFailed)
                }
            }
        }
    }
}

private enum MedicationPhotoSaveError: String, Error, Identifiable, LocalizedError {
    case accessDenied
    case saveFailed

    var id: String { rawValue }

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Allow Photos access in Settings to save this medication image."
        case .saveFailed:
            "The medication image could not be saved to Photos. Try again."
        }
    }
}
