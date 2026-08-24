import Foundation

struct MedicationScanResult: Sendable {
    let medicineName: String?
    let amount: Decimal?
    let unit: MedicineUnit?
    let expiryDate: Date?
    let repeatsRemaining: Int?
    let repeatsAuthorised: Int?
    let scriptNumber: String?
    let prescriber: String?
    let rawText: String
    let confidence: Float
    var imageData: Data?
    var imageFileExtension: String

    var scannedImageData: Data? {
        get { imageData }
        set { imageData = newValue }
    }

    init(
        medicineName: String?,
        amount: Decimal?,
        unit: MedicineUnit?,
        expiryDate: Date?,
        repeatsRemaining: Int?,
        repeatsAuthorised: Int?,
        scriptNumber: String?,
        prescriber: String?,
        rawText: String,
        confidence: Float,
        imageData: Data? = nil,
        scannedImageData: Data? = nil,
        imageFileExtension: String = "jpg"
    ) {
        self.medicineName = medicineName
        self.amount = amount
        self.unit = unit
        self.expiryDate = expiryDate
        self.repeatsRemaining = repeatsRemaining
        self.repeatsAuthorised = repeatsAuthorised
        self.scriptNumber = scriptNumber
        self.prescriber = prescriber
        self.rawText = rawText
        self.confidence = confidence
        self.imageData = imageData ?? scannedImageData
        self.imageFileExtension = imageFileExtension
    }
}
