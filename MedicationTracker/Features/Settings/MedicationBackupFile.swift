import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let medicationBackup = UTType(
        exportedAs: "dev.jusso.medicationtracker.backup"
    )
}

struct MedicationBackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.medicationBackup, .data] }
    static var writableContentTypes: [UTType] { [.medicationBackup] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw BackupRestoreError.invalidArchive
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
