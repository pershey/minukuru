import Foundation

struct PremiumCatalog: Decodable, Equatable {
    let standardCount: Int
    let realWorldCount: Int

    var isValid: Bool {
        standardCount >= 0 && standardCount <= 100_000 && realWorldCount >= 0 && realWorldCount <= 100_000
    }
}

enum MonetizationConfig {
    static let premiumProductID = "com.naoyaochiai.minukuru.premium"

    static let admobApplicationID = "ca-app-pub-7844017135115297~6684600489"
    static let admobBannerUnitID = "ca-app-pub-7844017135115297/9721827369"
}
