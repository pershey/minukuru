import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ZStack {
            homeBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        appViewModel.showSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MinukuruTheme.primary)
                            .padding(12)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(appViewModel.settings.isHiraganaMode ? "せってい" : "設定")
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer(minLength: 8)

                MinukuruLogoView(style: .vertical)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)

                Spacer(minLength: 0)

                VStack(spacing: 24) {
                    Text(appViewModel.settings.isHiraganaMode
                         ? "ぶんしょうの なかに まぎれた うそや いいすぎを みつけて、\nじょうほうを うのみに しない れんしゅうを する アプリです。"
                         : "文章の中にまぎれた嘘や言いすぎを見つけて、\n情報をうのみにしない練習をするアプリです。")
                        .font(.body.weight(.medium))
                        .foregroundStyle(MinukuruTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)

                    Button {
                        appViewModel.showModes()
                    } label: {
                        Text(appViewModel.settings.isHiraganaMode ? "はじめる" : "はじめる")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(MinukuruTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityLabel("はじめる")
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
            .padding(.top, 8)
        }
    }

    private var homeBackground: some View {
        Color.white
    }
}
