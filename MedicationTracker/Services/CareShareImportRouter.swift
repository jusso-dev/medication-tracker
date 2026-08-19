import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CareShareImportRouter {
    static let shared = CareShareImportRouter()

    var pendingPackage: CareSharePackage?
    var errorMessage: String?
    var isLoading = false
    var isImporting = false
    var importSummary: CareShareImportSummary?
    var importErrorMessage: String?

    private var activeRequestID: UUID?
    private var importTask: Task<Void, Never>?

    private init() {}

    func open(_ url: URL) {
        guard url.pathExtension.lowercased() == "medcare" else {
            return
        }
        guard !isImporting else {
            errorMessage = "Finish the current care snapshot import first."
            return
        }

        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil
        pendingPackage = nil
        importSummary = nil
        importErrorMessage = nil
        Task {
            do {
                let package = try await Task.detached {
                    try CareShareCodec.decode(contentsOf: url)
                }.value
                guard activeRequestID == requestID else { return }
                pendingPackage = package
            } catch {
                guard activeRequestID == requestID else { return }
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "The care snapshot could not be opened."
            }
            if activeRequestID == requestID {
                isLoading = false
            }
        }
    }

    func importPackage(
        _ package: CareSharePackage,
        modelContainer: ModelContainer
    ) {
        guard !isImporting else { return }
        isImporting = true
        importSummary = nil
        importErrorMessage = nil
        importTask = Task {
            let importer = CareShareImporter(modelContainer: modelContainer)
            do {
                importSummary = try await importer.importPackage(package)
            } catch {
                importErrorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "The care snapshot could not be imported."
            }
            isImporting = false
            importTask = nil
        }
    }

    func clear() {
        guard !isImporting else { return }
        pendingPackage = nil
        errorMessage = nil
        importSummary = nil
        importErrorMessage = nil
        activeRequestID = nil
        isLoading = false
    }
}
