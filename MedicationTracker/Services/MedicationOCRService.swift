import Foundation
import ImageIO
import UIKit
import Vision

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
    let scannedImageData: Data?
}

actor MedicationOCRService {
    func scan(imageData: [Data]) throws -> MedicationScanResult {
        var lines: [String] = []
        var confidences: [Float] = []

        for data in imageData {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-AU", "en-US"]
            request.usesLanguageCorrection = true
            request.customWords = AustralianMedicineCatalogue.entries.flatMap(\.searchTerms)

            let handler = VNImageRequestHandler(data: data, options: [:])
            try handler.perform([request])

            for observation in request.results ?? [] {
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence >= 0.35 else {
                    continue
                }
                lines.append(candidate.string)
                confidences.append(candidate.confidence)
            }
        }

        return Self.parse(
            lines: lines,
            confidence: confidences.isEmpty
                ? 0
                : confidences.reduce(0, +) / Float(confidences.count),
            scannedImageData: Self.preparedStoredImage(from: imageData.first)
        )
    }

    nonisolated static func parse(
        lines: [String],
        confidence: Float = 1,
        calendar: Calendar = .current,
        scannedImageData: Data? = nil
    ) -> MedicationScanResult {
        let rawText = lines.joined(separator: "\n")
        let catalogueMatch = AustralianMedicineCatalogue.match(in: rawText)
        let dose = parseDose(in: lines)
        let repeatsRemaining = integer(
            matching: #"(?:REPEATS?|RPTS?)\s+(?:REMAINING|LEFT)\s*[:\-]?\s*(\d+)"#,
            in: rawText
        ) ?? integer(
            matching: #"(?m)^\s*(?:REPEATS?|RPTS?)\s*[:\-]?\s*(\d+)\s*$"#,
            in: rawText
        )

        return MedicationScanResult(
            medicineName: catalogueMatch?.genericName
                ?? fallbackMedicineName(
                    in: lines,
                    strengthLineIndex: dose?.sourceIndex
                ),
            amount: dose?.amount,
            unit: dose?.unit,
            expiryDate: parseExpiryDate(in: rawText, calendar: calendar),
            repeatsRemaining: repeatsRemaining,
            repeatsAuthorised: integer(
                matching: #"(?:ORIGINAL|TOTAL|AUTHORI[ZS]ED)\s+REPEATS?\s*[:\-]?\s*(\d+)"#,
                in: rawText
            ),
            scriptNumber: capture(
                matching: #"(?:SCRIPT|RX)\s*(?:NO|NUMBER|#)?\s*[:\-]?\s*([A-Z0-9\-]{4,})"#,
                in: rawText
            ),
            prescriber: capture(
                matching: #"(?:PRESCRIBER|DOCTOR|DR\.?)\s*[:\-]?\s*([A-Z][A-Z .'\\-]{2,40})"#,
                in: rawText
            )?.trimmingCharacters(in: .whitespacesAndNewlines).capitalized,
            rawText: rawText,
            confidence: confidence,
            scannedImageData: scannedImageData
        )
    }

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

    nonisolated private static func parseDose(
        in lines: [String]
    ) -> (
        amount: Decimal,
        unit: MedicineUnit,
        sourceLine: String,
        sourceIndex: Int
    )? {
        let volumeDosePattern =
            #"(?:\b(?:TAKE|GIVE|USE)\b(?:\s+(?:BY\s+MOUTH|ORALLY))?\s*|\bDOSE\b\s*[:=\-]\s*)(\d+(?:[.,]\d+)?)\s*ML\b"#
        for (index, line) in lines.enumerated() {
            if let value = capture(
                matching: volumeDosePattern,
                in: line,
                group: 1
            ),
            let amount = Decimal(
                string: value.replacingOccurrences(of: ",", with: ".")
            ) {
                return (amount, .mL, line, index)
            }
        }

        let concentrationPattern =
            #"(\d+(?:[.,]\d+)?)\s*(MG|G)\s*(?:/|PER)\s*(?:\d+(?:[.,]\d+)?\s*)?ML\b"#
        for (index, line) in lines.enumerated() {
            if let result = parsedStrength(
                pattern: concentrationPattern,
                line: line
            ) {
                return (result.amount, result.unit, line, index)
            }
        }

        let strengthPattern = #"(\d+(?:[.,]\d+)?)\s*(MG|G)\b"#
        let candidates = lines.enumerated().compactMap { index, line -> (
            amount: Decimal,
            unit: MedicineUnit,
            sourceLine: String,
            sourceIndex: Int,
            score: Int
        )? in
            guard let result = parsedStrength(pattern: strengthPattern, line: line) else {
                return nil
            }
            let upper = line.uppercased()
            let isPackaging = ["NET", "CONTENTS", "PACK SIZE", "TOTAL WEIGHT"]
                .contains(where: upper.contains)
            let hasProductWords = ["TABLET", "CAPSULE", "SOLUTION", "SUSPENSION"]
                .contains(where: upper.contains)
            return (
                result.amount,
                result.unit,
                line,
                index,
                (isPackaging ? -100 : 0) + (hasProductWords ? 20 : 0)
            )
        }
        guard let best = candidates.max(by: { $0.score < $1.score }),
              best.score >= 0 else {
            return nil
        }
        return (best.amount, best.unit, best.sourceLine, best.sourceIndex)
    }

    nonisolated private static func parsedStrength(
        pattern: String,
        line: String
    ) -> (amount: Decimal, unit: MedicineUnit)? {
        guard let value = capture(matching: pattern, in: line, group: 1),
              let rawUnit = capture(matching: pattern, in: line, group: 2),
              let amount = Decimal(
                  string: value.replacingOccurrences(of: ",", with: ".")
              ) else {
            return nil
        }
        let unit: MedicineUnit = rawUnit.uppercased() == "G" ? .g : .mg
        return (amount, unit)
    }

    nonisolated private static func parseExpiryDate(
        in text: String,
        calendar: Calendar
    ) -> Date? {
        let labels = "(?:EXP(?:IRY)?|USE\\s+BY|VALID\\s+UNTIL)"

        if let day = integer(
            matching: "\(labels)\\s*[:\\-]?\\s*(\\d{1,2})[/.\\-](\\d{1,2})[/.\\-](\\d{2,4})",
            in: text,
            group: 1
        ),
        let month = integer(
            matching: "\(labels)\\s*[:\\-]?\\s*(\\d{1,2})[/.\\-](\\d{1,2})[/.\\-](\\d{2,4})",
            in: text,
            group: 2
        ),
        let yearValue = integer(
            matching: "\(labels)\\s*[:\\-]?\\s*(\\d{1,2})[/.\\-](\\d{1,2})[/.\\-](\\d{2,4})",
            in: text,
            group: 3
        ) {
            let year = yearValue < 100 ? 2_000 + yearValue : yearValue
            return validatedDate(
                year: year,
                month: month,
                day: day,
                calendar: calendar
            )
        }

        if let month = integer(
            matching: "\(labels)\\s*[:\\-]?\\s*(\\d{1,2})[/.\\-](\\d{2,4})",
            in: text,
            group: 1
        ),
        let yearValue = integer(
            matching: "\(labels)\\s*[:\\-]?\\s*(\\d{1,2})[/.\\-](\\d{2,4})",
            in: text,
            group: 2
        ) {
            let year = yearValue < 100 ? 2_000 + yearValue : yearValue
            guard (1...12).contains(month) else { return nil }
            return endOfMonth(year: year, month: month, calendar: calendar)
        }

        if let monthName = capture(
            matching: "\(labels)\\s*[:\\-]?\\s*([A-Z]{3,9})\\s+(\\d{4})",
            in: text,
            group: 1
        ),
        let year = integer(
            matching: "\(labels)\\s*[:\\-]?\\s*([A-Z]{3,9})\\s+(\\d{4})",
            in: text,
            group: 2
        ),
        let month = monthNumber(monthName) {
            return endOfMonth(year: year, month: month, calendar: calendar)
        }

        return nil
    }

    nonisolated private static func endOfMonth(
        year: Int,
        month: Int,
        calendar: Calendar
    ) -> Date? {
        guard let start = calendar.date(from: DateComponents(year: year, month: month)),
              let next = calendar.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }
        return calendar.date(byAdding: .day, value: -1, to: next)
    }

    nonisolated private static func validatedDate(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar
    ) -> Date? {
        guard (1...12).contains(month),
              (1...31).contains(day),
              let date = calendar.date(
                  from: DateComponents(year: year, month: month, day: day)
              ) else {
            return nil
        }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard components.year == year,
              components.month == month,
              components.day == day else {
            return nil
        }
        return date
    }

    nonisolated private static func monthNumber(_ value: String) -> Int? {
        let symbols = Calendar(identifier: .gregorian).monthSymbols
        let key = value.lowercased()
        return symbols.firstIndex {
            $0.lowercased().hasPrefix(String(key.prefix(3)))
        }.map { $0 + 1 }
    }

    nonisolated private static func fallbackMedicineName(
        in lines: [String],
        strengthLineIndex: Int?
    ) -> String? {
        guard let strengthLineIndex,
              lines.indices.contains(strengthLineIndex) else {
            return nil
        }
        let unsafeLabelPatterns = [
            #"\bEXP\b"#, #"\bEXPIRY\b"#, #"\bUSE\s+BY\b"#,
            #"\bBATCH\b"#, #"\bLOT\b"#, #"\bSCRIPT\b"#, #"\bREPEATS?\b"#,
            #"\bPATIENT\b"#, #"\bPHARMACY\b"#, #"\bPRESCRIBER\b"#,
            #"\bDOCTOR\b"#, #"\bTAKE\b"#, #"\bGIVE\b"#, #"\bDOSE\b"#,
            #"\bUSE\b"#
        ]
        let strengthLine = lines[strengthLineIndex]
        let upper = strengthLine.uppercased()
        if !containsAnyPattern(unsafeLabelPatterns, in: upper) {
            let cleaned = strengthLine
                .replacingOccurrences(
                    of: #"\d+(?:[.,]\d+)?\s*(?:MG|G)(?:\s*(?:/|PER)\s*(?:\d+(?:[.,]\d+)?\s*)?ML)?"#,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                .replacingOccurrences(
                    of: #"\b(?:TABLETS?|CAPSULES?|ORAL|SOLUTION|SUSPENSION)\b"#,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines.union(.punctuationCharacters)
                )
            if cleaned.count <= 60, cleaned.filter(\.isLetter).count >= 4 {
                return cleaned.capitalized
            }
        }

        let excludedPatterns = unsafeLabelPatterns + [
            #"\bTABLETS?\b"#, #"\bCAPSULES?\b"#, #"\bORAL\b"#,
            #"\bSOLUTION\b"#, #"\bSUSPENSION\b"#
        ]
        let adjacentIndices = [strengthLineIndex - 1, strengthLineIndex + 1]
        for index in adjacentIndices where lines.indices.contains(index) {
            let candidate = lines[index].trimmingCharacters(
                in: .whitespacesAndNewlines.union(.punctuationCharacters)
            )
            let candidateUpper = candidate.uppercased()
            guard candidate.count <= 60,
                  candidate.filter(\.isLetter).count >= 4,
                  !containsAnyPattern(excludedPatterns, in: candidateUpper),
                  candidate.rangeOfCharacter(from: .decimalDigits) == nil else {
                continue
            }
            return candidate.capitalized
        }
        return nil
    }

    nonisolated private static func containsAnyPattern(
        _ patterns: [String],
        in text: String
    ) -> Bool {
        patterns.contains {
            text.range(
                of: $0,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    nonisolated private static func integer(
        matching pattern: String,
        in text: String,
        group: Int = 1
    ) -> Int? {
        capture(matching: pattern, in: text, group: group).flatMap(Int.init)
    }

    nonisolated private static func capture(
        matching pattern: String,
        in text: String,
        group: Int = 1
    ) -> String? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              group < match.numberOfRanges,
              let valueRange = Range(match.range(at: group), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }
}
