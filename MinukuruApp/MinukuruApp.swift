import SwiftUI
import GoogleMobileAds

@main
struct MinukuruApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: MinukuruAppDelegate
    @StateObject private var purchaseManager: PurchaseManager
    @StateObject private var appViewModel: AppViewModel

    init() {
        let purchaseManager = PurchaseManager()
        _purchaseManager = StateObject(wrappedValue: purchaseManager)
        _appViewModel = StateObject(wrappedValue: AppViewModel(purchaseManager: purchaseManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
                .preferredColorScheme(.light)
                .task {
                    await purchaseManager.prepare()
                }
        }
    }
}

final class MinukuruAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MobileAds.shared.start(completionHandler: nil)
        return true
    }
}
