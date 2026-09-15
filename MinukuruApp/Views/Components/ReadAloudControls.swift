import SwiftUI

struct ReadAloudControls: View {
    @StateObject private var reader = SpeechReader()
    let text: String
    var isHiraganaMode = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                readButton
                repeatButton
            }

            VStack(alignment: .leading, spacing: 10) {
                readButton
                repeatButton
            }
        }
        .onDisappear {
            reader.stop()
        }
    }

    private var readButton: some View {
        Button {
            if reader.isSpeaking {
                reader.stop()
            } else {
                reader.read(text)
            }
        } label: {
            Label(
                reader.isSpeaking
                    ? (isHiraganaMode ? "とめる" : "停止")
                    : (isHiraganaMode ? "よみあげる" : "読み上げる"),
                systemImage: reader.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
            )
            .font(.headline.weight(.semibold))
            .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(MinukuruTheme.primary)
        .accessibilityHint(reader.isSpeaking ? "読み上げを止めます" : "画面の文章を読み上げます")
    }

    @ViewBuilder
    private var repeatButton: some View {
        if reader.hasReadText, !reader.isSpeaking {
            Button {
                reader.repeatLast()
            } label: {
                Label(
                    isHiraganaMode ? "もういちど きく" : "もう一度聞く",
                    systemImage: "arrow.counterclockwise"
                )
                .font(.headline.weight(.semibold))
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(MinukuruTheme.primary)
            .accessibilityHint("直前の文章をもう一度読み上げます")
        }
    }
}
