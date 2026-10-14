import Foundation

struct ScanImageStore: Sendable {
    let directory: URL

    static let shared: ScanImageStore = {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("ScanImages", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return ScanImageStore(directory: directory)
    }()

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func url(for medicineID: UUID, fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return directory.appendingPathComponent(fileName)
    }

    func url(for medicineID: UUID, fileExtension: String) -> URL {
        directory.appendingPathComponent("\(medicineID.uuidString).\(normalizedExtension(fileExtension))")
    }

    func read(medicineID: UUID, fileName: String?) -> Data? {
        guard let url = url(for: medicineID, fileName: fileName) else { return nil }
        return try? Data(contentsOf: url)
    }

    @discardableResult
    func write(_ data: Data, medicineID: UUID, fileExtension: String) throws -> String {
        let ext = normalizedExtension(fileExtension)
        let fileName = "\(medicineID.uuidString).\(ext)"
        let destination = directory.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)
        return fileName
    }

    func delete(medicineID: UUID, fileName: String?) {
        if let url = url(for: medicineID, fileName: fileName) {
            try? FileManager.default.removeItem(at: url)
            return
        }
        for ext in ["jpg", "jpeg", "png"] {
            let url = directory.appendingPathComponent("\(medicineID.uuidString).\(ext)")
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func fileExtension(for data: Data) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }
        return "jpg"
    }

    private func normalizedExtension(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "jpeg" || trimmed == "jpg" { return "jpg" }
        if trimmed == "png" { return "png" }
        return "jpg"
    }
}
