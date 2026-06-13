import SwiftUI

struct MinukuruLogoView: View {
    enum LayoutStyle {
        case vertical
        case horizontal
    }

    let style: LayoutStyle
    var showsTagline: Bool = true

    var body: some View {
        switch style {
        case .vertical:
            verticalLogo
        case .horizontal:
            horizontalLogo
        }
    }

    private var verticalLogo: some View {
        VStack(spacing: 2) {
            Image("TitleLogoVertical")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 360)

            if showsTagline {
                Text("やさしい知性で、うのみをへらす")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MinukuruTheme.primary)
                    .tracking(0.2)
                    .multilineTextAlignment(.center)
                    .padding(.top, -4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ミヌクル。やさしい知性で、うのみをへらす")
    }

    private var horizontalLogo: some View {
        Image("HeaderLogoHorizontal")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 320)
            .accessibilityLabel("ミヌクル")
    }
}
