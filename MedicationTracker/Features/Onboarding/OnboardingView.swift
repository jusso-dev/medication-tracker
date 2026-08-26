import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    @State private var page = 0

    private let pages = OnboardingPage.all

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Medication Tracker", systemImage: "cross.case.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                Spacer()
                Button("Skip") { onComplete() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                    .minimumTapTarget()
                    .accessibilityIdentifier("onboarding.skip")
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            TabView(selection: $page) {
                ForEach(pages) { item in
                    OnboardingPageView(page: item)
                        .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages) { item in
                    Capsule()
                        .fill(item.id == page ? AppTheme.blue : AppTheme.divider)
                        .frame(width: item.id == page ? 28 : 8, height: 8)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: page)
                        .accessibilityHidden(true)
                }
            }
            .padding(.bottom, 22)

            HStack(spacing: 12) {
                if page > 0 {
                    Button("Back") {
                        move(to: page - 1)
                    }
                    .font(.headline)
                    .foregroundStyle(AppTheme.blue)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.blueFill)
                    .clipShape(.capsule)
                    .accessibilityIdentifier("onboarding.back")
                }

                Button(page == pages.count - 1 ? "Get started" : "Continue") {
                    if page == pages.count - 1 {
                        onComplete()
                    } else {
                        move(to: page + 1)
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppTheme.blue)
                .clipShape(.capsule)
                .accessibilityIdentifier(
                    page == pages.count - 1
                        ? "onboarding.complete"
                        : "onboarding.continue"
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func move(to destination: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            page = destination
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CircularSymbol(
                    name: page.symbol,
                    foreground: page.tint,
                    background: page.tint.opacity(0.12),
                    size: 96
                )
                .padding(.top, 36)

                VStack(spacing: 10) {
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.title)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(page.detail)
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(page.points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.green)
                                .accessibilityHidden(true)
                            Text(point)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .medicationCard()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id: Int
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let points: [String]

    static let all = [
        OnboardingPage(
            id: 0,
            symbol: "pill.fill",
            tint: AppTheme.blue,
            title: "Know what to take",
            detail: "Keep medications, schedules, and dose history together in a clear daily view.",
            points: [
                "Add scheduled or as-needed medication",
                "Use exact strengths, including 12.5 mg",
                "Choose an end date or take it indefinitely"
            ]
        ),
        OnboardingPage(
            id: 1,
            symbol: "text.viewfinder",
            tint: AppTheme.green,
            title: "Scan, then confirm",
            detail: "On-device text recognition can prefill label details while you stay in control.",
            points: [
                "Review every detected detail before saving",
                "Keep the scanned label image with the medication",
                "Your scan is processed on this device"
            ]
        ),
        OnboardingPage(
            id: 2,
            symbol: "externaldrive.badge.checkmark",
            tint: AppTheme.blue,
            title: "Keep your data safe",
            detail: "Medication data stays on device unless you choose to export or share it.",
            points: [
                "Export a full backup from Settings",
                "Restore medicines, images, scripts, and dose history",
                "Optional app lock protects your private log"
            ]
        )
    ]
}
