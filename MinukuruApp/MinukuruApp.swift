import SwiftUI

@main
struct MinukuruApp: App {
    @StateObject private var purchaseManager: PurchaseManager
    @StateObject private var appViewModel: AppViewModel
    @StateObject private var adPrivacy = AdPrivacyState()

    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingResetState"),
           let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
#endif
        let purchaseManager = PurchaseManager()
        _purchaseManager = StateObject(wrappedValue: purchaseManager)
        _appViewModel = StateObject(wrappedValue: AppViewModel(purchaseManager: purchaseManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
                .environmentObject(adPrivacy)
                .preferredColorScheme(.light)
                .task {
                    await purchaseManager.prepare()
                }
        }
    }
}
