import SwiftUI

struct SectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(AppTheme.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct CircularSymbol: View {
    let name: String
    var foreground = AppTheme.blue
    var background = AppTheme.blueFill
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: name)
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background)
            .clipShape(.circle)
            .accessibilityHidden(true)
    }
}

struct EmptyActionCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    CircularSymbol(name: symbol, size: 58)
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.blue)
                        .clipShape(.circle)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
        .medicationCard()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the creation wizard")
    }
}

struct MedicineRowContent: View {
    let medicine: Medicine
    var showsPlan = false

    var body: some View {
        HStack(spacing: 12) {
            CircularSymbol(name: "pill")

            VStack(alignment: .leading, spacing: 3) {
                Text(medicine.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                Text(medicine.strengthText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                if showsPlan, let plan = medicine.plan {
                    Text(plan.title)
                        .font(.caption)
                        .foregroundStyle(AppTheme.blue)
                }
            }

            Spacer(minLength: 8)

            Label(medicine.shortScheduleLabel, systemImage: "hourglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.blueFill)
                .clipShape(.capsule)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(medicine.displayName), \(medicine.shortScheduleLabel)"
        )
    }
}

struct DayCircles: View {
    let selectedDays: Set<Int>
    var onToggle: ((Int) -> Void)?

    private let symbols = ["S", "M", "T", "W", "T", "F", "S"]
    private let names = [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    if let onToggle {
                        Button {
                            onToggle(day)
                        } label: {
                            circle(day: day)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(names[day - 1])
                        .accessibilityValue(selectedDays.contains(day) ? "Selected" : "Not selected")
                        .accessibilityAddTraits(.isToggle)
                    } else {
                        circle(day: day)
                            .accessibilityLabel(
                                "\(names[day - 1]), \(selectedDays.contains(day) ? "selected" : "not selected")"
                            )
                    }
                }
            }
        }
    }

    private func circle(day: Int) -> some View {
        Text(symbols[day - 1])
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selectedDays.contains(day) ? Color.white : AppTheme.text)
            .frame(width: 44, height: 44)
            .background(selectedDays.contains(day) ? AppTheme.blue : AppTheme.blueFill)
            .clipShape(.circle)
    }
}

struct SheetIconButton: View {
    let symbol: String
    let label: String
    var tint = AppTheme.title
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(tint)
                .minimumTapTarget()
                .background(AppTheme.blueFill)
                .clipShape(.circle)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(label)
    }
}

struct FooterActionButton: View {
    let title: String
    let symbol: String
    let foreground: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(background)
                .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
        }
        .buttonStyle(.plain)
    }
}

struct DetailLabelRow<Content: View>: View {
    let title: String
    let symbol: String
    let content: Content

    init(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CircularSymbol(name: symbol)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                content
                    .foregroundStyle(AppTheme.title)
            }
            Spacer()
        }
        .medicationCard()
    }
}
