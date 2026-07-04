import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ZStack {
            MinukuruTheme.background
                .ignoresSafeArea()

            switch appViewModel.screen {
            case .home:
                HomeView()
            case .modeSelect:
                ModeSelectView()
            case .quiz(let viewModel):
                QuizView(viewModel: viewModel)
            case .result(let viewModel, let result):
                ResultView(viewModel: viewModel, result: result)
            case .stats:
                StatsView()
            case .settings:
                SettingsView()
            case .premium(let origin):
                PremiumView(origin: origin)
            }
        }
        .animation(.spring(duration: 0.28), value: appViewModel.screenID)
        .task {
            await appViewModel.refreshQuestionContentIfNeeded()
        }
    }
}
