import SwiftUI
import GoogleMobileAds

struct BannerAdView: View {
    @EnvironmentObject private var adPrivacy: AdPrivacyState
    @State private var creative: AdCreative?
    @State private var isReporting = false

    var body: some View {
        Group {
            if adPrivacy.canRequestAds {
                VStack(alignment: .leading, spacing: 12) {
                    if creative != nil {
                        Text("広告").font(.caption.weight(.bold))
                    }
                    BannerAdRepresentable { creative = $0 }
                        .frame(height: creative == nil ? 0 : 50)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .allowsHitTesting(creative != nil)
                        .accessibilityHidden(creative == nil)
                    if let creative {
                        Button("不適切な広告を報告") { isReporting = true }
                            .font(.footnote)
                            .frame(minHeight: 44)
                            .padding(.top, 12)
                            .sheet(isPresented: $isReporting) { reportSheet(creative) }
                    }
                }
                .padding(.top, creative == nil ? 0 : 24)
                .accessibilityIdentifier("result-ad-slot")
            }
        }
        .task { await adPrivacy.prepareIfNeeded() }
        .onChange(of: adPrivacy.canRequestAds) { _, allowed in
            if !allowed { creative = nil }
        }
    }

    private func reportSheet(_ creative: AdCreative) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("不適切だと感じた理由を、保護者と一緒に伝えられます。表示時刻と、広告が返した確認番号が含まれます。")
                    Text(creative.report).font(.footnote).textSelection(.enabled)
                    if let url = creative.mailURL {
                        Link("メールを開く", destination: url).frame(minHeight: 44)
                    }
                    ShareLink(item: creative.report) { Label("報告内容を共有", systemImage: "square.and.arrow.up") }
                }
                .padding(20)
            }
            .navigationTitle("広告の報告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { isReporting = false }
                }
            }
        }
    }
}

private struct AdCreative {
    let responseID: String?
    let receivedAt = Date()

    var report: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "不明"
        return """
        ミヌクルの広告について
        送付先: \(QuestionFeedback.recipient)
        配置: 練習セットの結果
        アプリ: \(version)
        受信時刻: \(receivedAt.formatted(date: .numeric, time: .standard))
        広告確認番号: \(responseID ?? "番号なし")

        気になった内容:
        """
    }

    var mailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = QuestionFeedback.recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: "ミヌクルの広告について"),
            URLQueryItem(name: "body", value: report)
        ]
        return components.url
    }
}

private struct BannerAdRepresentable: UIViewRepresentable {
    let onCreativeChange: (AdCreative?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCreativeChange: onCreativeChange) }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let bannerView = BannerView(adSize: AdSizeBanner)
#if DEBUG || targetEnvironment(simulator)
        bannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716"
#else
        bannerView.adUnitID = MonetizationConfig.admobBannerUnitID
#endif
        bannerView.delegate = context.coordinator
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        bannerView.load(Request())
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        let onCreativeChange: (AdCreative?) -> Void

        init(onCreativeChange: @escaping (AdCreative?) -> Void) {
            self.onCreativeChange = onCreativeChange
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onCreativeChange(AdCreative(responseID: bannerView.responseInfo?.responseIdentifier))
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            onCreativeChange(nil)
        }
    }
}
