import SwiftUI

struct UtilityCardView: View {
    let utility: UtilityInfo
    var style: CardStyle = .dashboard

    enum CardStyle {
        case dashboard
        case compact
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: utility.iconName)
                .font(.system(size: style == .dashboard ? 32 : 24))
                .foregroundStyle(.orange)

            Text(utility.name)
                .font(style == .dashboard ? .headline : .subheadline)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if style == .dashboard {
                Text(utility.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

#Preview {
    HStack {
        UtilityCardView(
            utility: UtilityInfo.allUtilities[0],
            style: .dashboard
        )
        UtilityCardView(
            utility: UtilityInfo.allUtilities[0],
            style: .compact
        )
    }
    .padding()
}
