import SwiftUI

struct OnboardingView: View {
    @AppStorage(SettingsKeys.hasCompletedOnboarding)
    private var hasCompletedOnboarding = false
    @State private var page = 0

    private let pages: [(symbol: String, title: String, body: String)] = [
        (
            "pills",
            "Add a medicine",
            "Type the name and strength, or pick from a scan. You can set days, times, and how long to take it."
        ),
        (
            "text.viewfinder",
            "Scan a label",
            "Point the camera at the printed label. Text stays on this device. The photo is kept so you can check it later."
        ),
        (
            "bell.badge",
            "Reminders and backup",
            "Turn on local reminders, then export a backup from Settings. Restore merges by id and will not wipe a failed file."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") {
                    finish()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .minimumTapTarget()
                .accessibilityIdentifier("onboarding.skip")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 22) {
                        CircularSymbol(name: item.symbol, size: 88)
                        Text(item.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.title)
                            .multilineTextAlignment(.center)
                        Text(item.body)
                            .font(.body)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == pages.count - 1 ? "Get started" : "Continue") {
                if page == pages.count - 1 {
                    finish()
                } else {
                    page += 1
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppTheme.blue)
            .clipShape(.capsule)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .accessibilityIdentifier(
                page == pages.count - 1 ? "onboarding.done" : "onboarding.continue"
            )
        }
        .background(AppTheme.background)
    }

    private func finish() {
        hasCompletedOnboarding = true
    }
}
