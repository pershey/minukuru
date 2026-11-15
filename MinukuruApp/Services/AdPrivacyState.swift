import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

@MainActor
final class AdPrivacyState: ObservableObject {
    @Published private(set) var canRequestAds = false
    @Published private(set) var needsPrivacyOptions = false
    @Published private(set) var privacyOptionsError = false
    private var hasRequestedConsentUpdate = false
    private var startedAds = false

    func prepareIfNeeded() async {
        guard !hasRequestedConsentUpdate else { return }
        hasRequestedConsentUpdate = true
        let parameters = RequestParameters()
        // 子供と保護者で端末を共用できるため、年齢を尋ねず子供向けに制限する。
        parameters.isTaggedForUnderAgeOfConsent = true
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            try Task.checkCancellation()
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            hasRequestedConsentUpdate = false
            canRequestAds = false
            return
        }
        await applyConsent()
    }

    func showPrivacyOptions() async {
        canRequestAds = false
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            privacyOptionsError = false
            await applyConsent()
        } catch {
            privacyOptionsError = true
        }
    }

    private func applyConsent() async {
        needsPrivacyOptions = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds else { return }
        if !startedAds {
            let configuration = MobileAds.shared.requestConfiguration
            configuration.tagForChildDirectedTreatment = true
            configuration.maxAdContentRating = .general
            configuration.publisherPrivacyPersonalizationState = .disabled
            startedAds = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                MobileAds.shared.start { _ in continuation.resume() }
            }
        }
        canRequestAds = ConsentInformation.shared.canRequestAds
    }
}
