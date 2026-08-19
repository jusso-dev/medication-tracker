import SwiftUI

struct ProximityShareAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                graphic(isNear: true)
            } else {
                PhaseAnimator([false, true]) { isNear in
                    graphic(isNear: isNear)
                } animation: { isNear in
                    isNear
                        ? .smooth(duration: 1.15)
                        : .easeInOut(duration: 1.0)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 210)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Two nearby iPhones ready to share a medication care snapshot")
    }

    private func graphic(isNear: Bool) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(AppTheme.blue.opacity(isNear ? 0.08 : 0.22), lineWidth: 2)
                    .frame(
                        width: CGFloat(70 + ring * 34),
                        height: CGFloat(70 + ring * 34)
                    )
                    .scaleEffect(isNear ? 1.18 : 0.78)
            }

            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(AppTheme.blue)
                .clipShape(.circle)
                .shadow(color: AppTheme.blue.opacity(0.25), radius: 10)
                .symbolEffect(.pulse, isActive: !reduceMotion)

            phone(side: .left)
                .offset(x: isNear ? -72 : -112, y: isNear ? 4 : 14)
                .rotationEffect(.degrees(isNear ? 7 : -4))

            phone(side: .right)
                .offset(x: isNear ? 72 : 112, y: isNear ? 4 : 14)
                .rotationEffect(.degrees(isNear ? -7 : 4))
        }
    }

    private func phone(side: HorizontalEdge) -> some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(.white)
            .frame(width: 86, height: 164)
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(AppTheme.title.opacity(0.16), lineWidth: 2)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(AppTheme.title)
                    .frame(width: 34, height: 10)
                    .padding(.top, 8)
            }
            .overlay {
                VStack(spacing: 10) {
                    CircularSymbol(name: side == .left ? "pill" : "heart.fill")
                    Text(side == .left ? "You" : "Loved one")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.title)
                }
            }
            .shadow(color: AppTheme.title.opacity(0.12), radius: 16, y: 8)
            .accessibilityHidden(true)
    }
}

private enum HorizontalEdge {
    case left
    case right
}
