import SwiftUI
import RevenueCat
import RevenueCatUI

struct ProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(PurchaseManager.self) private var purchases
    @State private var showCustomerCenter = false
    @State private var showBook = false
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 22) {
                    stats
                    subscriptionCard
                    group("Storyteller") {
                        SettingsRow(systemName: "person", title: "\(app.profile.firstName)'s portrait", detail: app.profile.relation)
                        divider
                        SettingsRow(systemName: "calendar", title: "Call slot", detail: "\(app.profile.day) \(app.profile.hour > 12 ? app.profile.hour - 12 : app.profile.hour) PM")
                        divider
                        SettingsRow(systemName: "hand.raised", title: "Topics to avoid", detail: "\(app.profile.avoid.count)")
                        divider
                        SettingsRow(systemName: "waveform", title: "Biographer voice", detail: app.profile.biographer)
                    }
                    group("The book") {
                        Button { showBook = true } label: { SettingsRow(systemName: "book.closed", title: "Order the printed book", detail: "€49") }
                            .buttonStyle(.plain)
                        divider
                        SettingsRow(systemName: "square.and.arrow.down", title: "Export everything", detail: "Audio · PDF")
                    }
                    group("Trust") {
                        SettingsRow(systemName: "key", title: "Archive guardian", detail: "Marc")
                        divider
                        SettingsRow(systemName: "lock.rectangle.stack", title: "Sealed stories", detail: "1")
                        divider
                        SettingsRow(systemName: "server.rack", title: "Data hosted in the EU", detail: "GDPR")
                    }
                    redLine
                    Button("Reset demo") { confirmReset = true }
                        .font(.ui(14, .medium)).foregroundStyle(Theme.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 18)
            }
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showCustomerCenter) { CustomerCenterView() }
        .sheet(isPresented: $showBook) { BookOrderSheet().presentationDetents([.medium]) }
        .confirmationDialog("Reset the demo?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) {
                AudioPlayer.shared.stop()
                purchases.resetDemo()
                app.resetDemo()
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .bottom) {
            Theme.heroGradient
                .overlay(alignment: .bottom) { Mountains().fill(.white.opacity(0.18)).frame(height: 120) }
                .overlay(alignment: .bottom) { Mountains(seed: 2).fill(.white.opacity(0.28)).frame(height: 80) }
                .frame(height: 250)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous))
            VStack(spacing: 6) {
                Text("Account").font(.display(18, .semibold)).foregroundStyle(.white).padding(.bottom, 16)
                Avatar(person: app.me.spec, size: 92, ring: true)
                Text("Claire Morel").font(.display(22, .bold)).foregroundStyle(Theme.ink).padding(.top, 6)
                Text("Gift buyer · Morel family").font(.ui(14)).foregroundStyle(Theme.mute)
            }
            .offset(y: 82)
        }
        .padding(.bottom, 92)
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat("\(app.stories.map(\.call).max() ?? 0)", "Calls")
            stat("\(app.stories.count)", "Stories")
            stat("\(Int(app.totalListeningTime / 60))m", "Her voice")
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 4) {
            Text(v).font(.display(22, .bold)).foregroundStyle(Theme.ink)
            Text(l).font(.ui(13)).foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 16)
    }

    private var subscriptionCard: some View {
        HStack(spacing: 14) {
            IconBadge(systemName: purchases.isFamilyActive ? "checkmark.seal.fill" : "gift.fill",
                      tint: purchases.isFamilyActive ? Theme.green : Theme.purple,
                      wash: purchases.isFamilyActive ? Theme.greenWash : Theme.purpleWash, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(purchases.isFamilyActive ? "Family plan active" : "Free welcome call")
                    .font(.ui(16, .semibold)).foregroundStyle(Theme.ink)
                Text(purchases.isFamilyActive
                     ? (purchases.expirationDate.map { "Renews \($0.formatted(date: .abbreviated, time: .omitted)) · via RevenueCat" } ?? "Lifetime archive")
                     : "Unlock 52 calls and the archive")
                    .font(.ui(13)).foregroundStyle(Theme.mute)
            }
            Spacer()
            Button(purchases.isFamilyActive ? "Manage" : "Upgrade") {
                if purchases.isFamilyActive && !purchases.isDemoMode { showCustomerCenter = true } else { app.showPaywall = true }
            }
            .font(.ui(14, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14).frame(height: 36)
            .background(Capsule().fill(Theme.cardGradient))
        }
        .card()
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.display(17, .semibold)).foregroundStyle(Theme.ink)
            VStack(spacing: 0) { content() }.card(padding: 16)
        }
    }

    private var divider: some View { Divider().overlay(Theme.hairline) }

    private var redLine: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill").foregroundStyle(Theme.red)
                Text("Our red line").font(.display(16, .semibold)).foregroundStyle(Theme.ink)
            }
            Text("Mémoire never clones a storyteller's voice to make them say words they didn't say. Every answer in the archive is a real excerpt of a real call. The biographer always says it is an AI, and \(app.profile.firstName) can say “stop” at any time.")
                .font(.ui(14)).foregroundStyle(Theme.inkSoft).lineSpacing(3)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.radiusL).fill(Color(hex: 0xFFF1F1)))
    }
}

struct Mountains: Shape {
    var seed: Double = 1
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        let steps = 9
        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let h = (sin(Double(i) * 1.7 + seed) + 1) / 2
            let y = rect.height * (0.15 + 0.75 * (i % 2 == 0 ? h : 1 - h * 0.6))
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Physical goods can't use in-app purchase: the book is paid on the web.
struct BookOrderSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    @State private var copies = 3
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The book of \(app.storytellerFirstName)'s life").font(.display(21, .semibold)).foregroundStyle(Theme.ink)
            Text("Hardcover, family photos, a QR code in every chapter that plays her voice. Printed in Europe.")
                .font(.ui(14)).foregroundStyle(Theme.mute)
            HStack {
                Text("Copies").font(.ui(16, .medium))
                Spacer()
                Stepper("\(copies)", value: $copies, in: 1...20).fixedSize()
            }
            .card()
            HStack {
                Text("Total").font(.ui(16, .semibold))
                Spacer()
                Text("€\(49 + (copies - 1) * 29)").font(.display(22, .bold)).foregroundStyle(Theme.blue)
            }
            Button { openURL(Config.bookCheckoutURL) } label: {
                Label("Continue to secure checkout", systemImage: "lock.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            Text("Opens our web checkout (Stripe). Apple doesn't allow in-app purchase for printed goods.")
                .font(.ui(11)).foregroundStyle(Theme.mute)
        }
        .padding(Theme.gutter)
    }
}
