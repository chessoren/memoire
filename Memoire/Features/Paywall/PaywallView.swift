import SwiftUI
import RevenueCat

/// Shown at the end of onboarding, once the buyer has already invested in the portrait.
/// Offerings come from RevenueCat, so prices and plans can be A/B tested without a release.
struct PaywallView: View {
    enum Context { case onboarding, upgrade }
    let context: Context
    var onFinish: (() -> Void)? = nil

    @Environment(AppState.self) private var app
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var selected: PurchaseManager.Plan?
    @State private var success = false

    private let included = [
        "A warm weekly call, nothing to install for them",
        "A written chapter after every call",
        "Their real voice, searchable by the whole family",
        "Unlimited family members, listening is free",
        "Never a synthetic copy of their voice",
        "Free first call — cancel before if they don't enjoy it",
    ]

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        if context == .upgrade {
                            CircleIconButton(systemName: "xmark", size: 40) { dismiss() }
                        }
                        Spacer()
                        Text("Plan details").font(.display(17, .semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Button("Restore") { Task { await purchases.restore() } }
                            .font(.ui(14, .medium)).foregroundStyle(Theme.mute)
                    }

                    hero

                    if purchases.isDemoMode {
                        Label("Demo store — no real charge. Add a RevenueCat key to use the Test Store.", systemImage: "info.circle")
                            .font(.ui(12)).foregroundStyle(Theme.mute)
                    }

                    VStack(spacing: 12) {
                        ForEach(purchases.plans) { plan in planRow(plan) }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("What's included").font(.display(18, .semibold)).foregroundStyle(Theme.ink)
                        ForEach(included, id: \.self) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(Theme.blue)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(Theme.blueWash))
                                Text(item).font(.ui(15)).foregroundStyle(Theme.inkSoft)
                            }
                        }
                    }
                    .card(padding: 20)

                    HStack(spacing: 12) {
                        IconBadge(systemName: "book.closed.fill", tint: Theme.orange, wash: Theme.orangeWash, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The printed book").font(.ui(15, .semibold)).foregroundStyle(Theme.ink)
                            Text("Ordered separately on the web (€49) when the year ends — with QR codes to their voice.")
                                .font(.ui(13)).foregroundStyle(Theme.mute)
                        }
                    }
                    .card()

                    Text("Gift plans are one-time purchases and never renew by surprise. Monthly renews until cancelled in Settings. Payment is handled by Apple through RevenueCat.")
                        .font(.ui(11)).foregroundStyle(Theme.mute)
                        .padding(.bottom, 120)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
            }
        }
        .safeAreaInset(edge: .bottom) { cta }
        .task {
            if purchases.plans.isEmpty { await purchases.loadOfferings() }
            selected = selected ?? purchases.plans.first
        }
        .onChange(of: purchases.plans) { _, plans in if selected == nil { selected = plans.first } }
        .overlay { if success { successOverlay } }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Avatar(person: AvatarSpec(name: app.profile.firstName, colors: [Color(hex: 0xFFD3A8), Theme.orange]), size: 46, ring: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mémoire for \(app.profile.firstName)").font(.display(18, .semibold))
                    Text("\(app.profile.day)s at \(app.profile.hour > 12 ? app.profile.hour - 12 : app.profile.hour) PM · with \(app.profile.biographer)")
                        .font(.ui(13)).opacity(0.85)
                }
            }
            Text(selected?.price ?? "€119.00")
                .font(.display(38, .bold))
                .contentTransition(.numericText())
            HStack(spacing: 10) {
                stat("52", "Calls")
                stat("1", "Book")
                stat("∞", "Listeners")
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusXL, style: .continuous).fill(Theme.cardGradient)
                .overlay(RippleDecoration(color: .white).clipShape(RoundedRectangle(cornerRadius: Theme.radiusXL)))
        )
        .shadow(color: Theme.blue.opacity(0.3), radius: 20, y: 10)
        .animation(.spring, value: selected)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(value).font(.display(15, .bold))
            Text(label).font(.ui(12, .medium)).opacity(0.85)
        }
        .padding(.horizontal, 12).frame(height: 34)
        .background(Capsule().fill(.white.opacity(0.18)))
    }

    private func planRow(_ plan: PurchaseManager.Plan) -> some View {
        let on = selected == plan
        return Button { withAnimation(.spring) { selected = plan } } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22)).foregroundStyle(on ? Theme.blue : Theme.hairline)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.title).font(.ui(16, .semibold)).foregroundStyle(Theme.ink)
                        if let badge = plan.badge {
                            Text(badge).font(.ui(11, .bold)).foregroundStyle(Theme.orange)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Theme.orangeWash))
                        }
                    }
                    Text(plan.subtitle).font(.ui(13)).foregroundStyle(Theme.mute).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Text(plan.price).font(.ui(15, .bold)).foregroundStyle(Theme.ink)
            }
            .card(padding: 16)
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusL).stroke(on ? Theme.blue : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var cta: some View {
        VStack(spacing: 10) {
            Button {
                guard let plan = selected else { return }
                Task {
                    purchases.setAttributes(profile: app.profile)
                    if await purchases.purchase(plan) {
                        withAnimation(.spring) { success = true }
                        try? await Task.sleep(for: .seconds(1.8))
                        finish()
                    }
                }
            } label: {
                HStack {
                    if purchases.isLoading { ProgressView().tint(.white) }
                    Text(purchases.isFamilyActive && context == .upgrade ? "Already active" : "Offer Mémoire to \(app.profile.firstName)")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(purchases.isLoading)
            if context == .onboarding {
                Button("Start with the free welcome call") { finish() }
                    .font(.ui(15, .semibold)).foregroundStyle(Theme.blue)
            }
            if let err = purchases.errorMessage {
                Text(err).font(.ui(12)).foregroundStyle(Theme.red).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(Theme.canvas.opacity(0.96).ignoresSafeArea())
    }

    private func finish() {
        if context == .upgrade { dismiss() } else { onFinish?() }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Theme.greenWash).frame(width: 96, height: 96)
                    Image(systemName: "gift.fill").font(.system(size: 40)).foregroundStyle(Theme.green)
                        .symbolEffect(.bounce, value: success)
                }
                Text("Gift confirmed").font(.display(22, .semibold)).foregroundStyle(Theme.ink)
                Text("\(app.profile.biographer) will call \(app.profile.firstName) this \(app.profile.day). You'll get the first story that evening.")
                    .font(.ui(15)).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: Theme.radiusXL).fill(.white))
            .padding(32)
            .transition(.scale.combined(with: .opacity))
        }
    }
}
