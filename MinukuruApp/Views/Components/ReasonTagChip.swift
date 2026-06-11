import SwiftUI

struct ReasonTagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .foregroundStyle(MinukuruTheme.primary)
            .background(isSelected ? MinukuruTheme.accentSoft : Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MinukuruTheme.primary.opacity(isSelected ? 0.9 : 0.25), lineWidth: 1.6)
            }
        }
        .buttonStyle(.plain)
    }
}
