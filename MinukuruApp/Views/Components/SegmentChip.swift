import SwiftUI

struct InlineSegmentChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.title3)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isSelected ? MinukuruTheme.accentSoft : Color.white.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? MinukuruTheme.primary : MinukuruTheme.stroke.opacity(0.9), lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

struct ScamAdSegmentCard: View {
    let text: String
    let isSelected: Bool
    let emphasis: Emphasis
    let action: () -> Void

    enum Emphasis {
        case badge
        case headline
        case body
        case cta
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(paddingInsets)
                .background(backgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(isSelected ? MinukuruTheme.primary : borderColor, lineWidth: isSelected ? 2.5 : 1.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        switch emphasis {
        case .badge:
            Text(text)
                .font(.headline.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
        case .headline:
            Text(text)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
        case .body:
            Text(text)
                .font(.title3)
                .foregroundStyle(.primary)
        case .cta:
            HStack(spacing: 10) {
                Text(text)
                    .font(.headline.weight(.bold))
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(isSelected ? MinukuruTheme.primary : .white)
        }
    }

    private var cornerRadius: CGFloat {
        emphasis == .cta ? 18 : 16
    }

    private var paddingInsets: EdgeInsets {
        switch emphasis {
        case .badge:
            EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        case .headline:
            EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        case .body:
            EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        case .cta:
            EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return emphasis == .cta ? MinukuruTheme.accentSoft : MinukuruTheme.accentSoft.opacity(0.9)
        }

        switch emphasis {
        case .badge:
            return MinukuruTheme.accentSoft
        case .headline:
            return Color.white.opacity(0.96)
        case .body:
            return Color.white.opacity(0.94)
        case .cta:
            return MinukuruTheme.primary
        }
    }

    private var borderColor: Color {
        switch emphasis {
        case .cta:
            return MinukuruTheme.primary.opacity(0.9)
        default:
            return MinukuruTheme.stroke
        }
    }
}
