import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.97, green: 0.98, blue: 1.00)
    static let surface = Color.white
    static let title = Color(red: 0.08, green: 0.18, blue: 0.31)
    static let text = Color(red: 0.17, green: 0.26, blue: 0.37)
    static let secondaryText = Color(red: 0.40, green: 0.48, blue: 0.57)
    static let blue = Color(red: 0.22, green: 0.49, blue: 0.88)
    static let blueFill = Color(red: 0.89, green: 0.94, blue: 1.00)
    static let blueFillStrong = Color(red: 0.77, green: 0.87, blue: 0.99)
    static let red = Color(red: 0.76, green: 0.21, blue: 0.24)
    static let redFill = Color(red: 1.00, green: 0.91, blue: 0.91)
    static let green = Color(red: 0.13, green: 0.50, blue: 0.32)
    static let greenFill = Color(red: 0.87, green: 0.97, blue: 0.91)
    static let divider = Color(red: 0.86, green: 0.90, blue: 0.95)

    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 16
}

struct MedicationCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(AppTheme.surface)
            .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .stroke(AppTheme.divider, lineWidth: 1)
            }
    }
}

extension View {
    func medicationCard() -> some View {
        modifier(MedicationCardModifier())
    }

    func minimumTapTarget() -> some View {
        frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
    }
}
