import Foundation
import RevenueCat
import SwiftUI

/// RevenueCat wrapper. Mémoire sells to the *buyer* (the child who gifts it),
/// so the offering mixes a 12-month gift (no surprise renewal), a monthly plan
/// for hesitant families, and a lifetime archive add-on. One entitlement —
/// `family` — unlocks weekly calls, chapters and the voice archive for everyone.
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    struct Plan: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        let price: String
        let badge: String?
        let package: Package?
        static func == (a: Plan, b: Plan) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    private(set) var plans: [Plan] = []
    private(set) var isFamilyActive = false
    private(set) var isLoading = false
    private(set) var activeProductID: String?
    private(set) var expirationDate: Date?
    var errorMessage: String?

    var isDemoMode: Bool { !Config.isRevenueCatConfigured }

    func configure() {
        if Config.isRevenueCatConfigured {
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
            Task {
                for await info in Purchases.shared.customerInfoStream { apply(info) }
            }
        } else {
            isFamilyActive = UserDefaults.standard.bool(forKey: "demoEntitlement")
        }
        Task { await loadOfferings() }
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }
        guard Config.isRevenueCatConfigured else { plans = Self.demoPlans; return }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else { plans = Self.demoPlans; return }
            plans = current.availablePackages.map(Self.plan(for:)).sorted { order($0) < order($1) }
        } catch {
            errorMessage = error.localizedDescription
            plans = Self.demoPlans
        }
    }

    private func order(_ p: Plan) -> Int {
        if p.title.hasPrefix("The Gift") { return 0 }
        if p.title == "Monthly" { return 1 }
        return 2
    }

    @discardableResult
    func purchase(_ plan: Plan) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        guard let package = plan.package else {
            // Demo build without a RevenueCat key: simulate the unlock so the flow can be shown.
            try? await Task.sleep(for: .seconds(1))
            unlockDemo(plan.id)
            return true
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            apply(result.customerInfo)
            return isFamilyActive
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async {
        guard Config.isRevenueCatConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        if let info = try? await Purchases.shared.restorePurchases() { apply(info) }
    }

    /// Tag the buyer with who the gift is for — lets RevenueCat segment by relation (mother, grandfather…).
    func setAttributes(profile: StorytellerProfile) {
        guard Config.isRevenueCatConfigured else { return }
        Purchases.shared.attribution.setAttributes([
            "storyteller_relation": profile.relation,
            "call_day": profile.day,
            "biographer_voice": profile.biographer,
        ])
    }

    private func apply(_ info: CustomerInfo) {
        let ent = info.entitlements[Config.entitlementID]
        isFamilyActive = ent?.isActive == true
        activeProductID = ent?.productIdentifier
        expirationDate = ent?.expirationDate
    }

    private func unlockDemo(_ id: String) {
        isFamilyActive = true
        activeProductID = id
        expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: .now)
        UserDefaults.standard.set(true, forKey: "demoEntitlement")
    }

    func resetDemo() {
        UserDefaults.standard.set(false, forKey: "demoEntitlement")
        if isDemoMode { isFamilyActive = false; activeProductID = nil }
    }

    // MARK: Mapping

    private static func plan(for p: Package) -> Plan {
        let id = p.storeProduct.productIdentifier
        let price = p.storeProduct.localizedPriceString
        switch true {
        case id.contains("gift") || id.contains("year") || p.packageType == .annual:
            return Plan(id: id, title: "The Gift · 12 months", subtitle: "52 calls, chapters, private podcast, voice archive. We remind you 2 months before renewal.", price: price + " / year", badge: "Most chosen", package: p)
        case id.contains("month") || p.packageType == .monthly:
            return Plan(id: id, title: "Monthly", subtitle: "Same as the Gift, cancel anytime.", price: price + " / month", badge: nil, package: p)
        default:
            return Plan(id: id, title: "Lifetime archive", subtitle: "Every recording kept and searchable, forever.", price: price, badge: "One time", package: p)
        }
    }

    static let demoPlans: [Plan] = [
        Plan(id: "memoire_gift_12m", title: "The Gift · 12 months", subtitle: "52 calls, chapters, private podcast, voice archive. We remind you 2 months before renewal.", price: "€119.00 / year", badge: "Most chosen", package: nil),
        Plan(id: "memoire_monthly", title: "Monthly", subtitle: "Same as the Gift, cancel anytime.", price: "€12.99 / month", badge: nil, package: nil),
        Plan(id: "memoire_lifetime_archive", title: "Lifetime archive", subtitle: "Every recording kept and searchable, forever.", price: "€79.00", badge: "One time", package: nil),
    ]
}
