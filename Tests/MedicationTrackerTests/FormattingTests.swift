import Foundation
import Testing
@testable import MedicationTracker

@Suite("Medication formatting")
struct FormattingTests {
    @Test("medicationDecimal accepts period and comma decimals")
    func decimalParsing() {
        #expect("12.5".medicationDecimal == Decimal(string: "12.5"))
        #expect("12,5".medicationDecimal == Decimal(string: "12.5"))
        #expect("½".medicationDecimal == Decimal(string: "0.5"))
        #expect("⅓".medicationDecimal == Decimal(string: "0.333"))
        #expect("¼".medicationDecimal == Decimal(string: "0.25"))
        #expect("¾".medicationDecimal == Decimal(string: "0.75"))
    }

    @Test("medicationFormatted prints 12.5 with a period")
    func decimalFormatting() throws {
        let value = try #require("12.5".medicationDecimal)
        #expect(value.medicationFormatted == "12.5")
        let commaValue = try #require("12,5".medicationDecimal)
        #expect(commaValue.medicationFormatted == "12.5")
    }
}
