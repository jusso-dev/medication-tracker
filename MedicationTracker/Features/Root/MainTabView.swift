import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        ZStack {
            AppTheme.background.ignoresSafeArea()

            switch router.selectedTab {
            case .history:
                NavigationStack { HistoryView() }
            case .today:
                NavigationStack { TodayView() }
            case .medications:
                NavigationStack { MedicationsCatalogView() }
            case .settings:
                NavigationStack { SettingsView() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $router.selectedTab)
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(selection == tab ? .white : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background {
                            if selection == tab {
                                Circle()
                                    .fill(AppTheme.blue)
                                    .frame(width: 46, height: 46)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityValue(selection == tab ? "Selected" : "")
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(8)
        .background(.white)
        .clipShape(.capsule)
        .overlay {
            Capsule().stroke(AppTheme.divider, lineWidth: 1)
        }
        .shadow(color: AppTheme.title.opacity(0.10), radius: 14, y: 6)
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(AppTheme.background)
    }
}
