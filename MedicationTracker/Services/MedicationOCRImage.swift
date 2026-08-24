import Foundation
import ImageIO
import UIKit

extension MedicationOCRService {
    nonisolated static func preparedStoredImage(from data: Data?) -> Data? {
        guard let data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_800
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return nil
        }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.78)
    }

    nonisolated static func parse(
        lines: [String],
        confidence: Float = 1,
        calendar: Calendar = .current,
        scannedImageData: Data?
    ) -> MedicationScanResult {
        var result = parse(
            lines: lines,
            confidence: confidence,
            calendar: calendar
        )
        result.scannedImageData = scannedImageData
        return result
    }
}
