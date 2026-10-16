import SwiftUI

enum Theme {
    static let bg1 = Color(red: 0.05, green: 0.06, blue: 0.14)
    static let bg2 = Color(red: 0.11, green: 0.08, blue: 0.22)
    static let sun = Color(red: 1.0, green: 0.70, blue: 0.20)
    static let moon = Color(red: 0.42, green: 0.62, blue: 1.0)
    static let good = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let bad = Color(red: 1.0, green: 0.36, blue: 0.40)
    static let text2 = Color.white.opacity(0.62)
}

func rounded(_ size: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: size, weight: w, design: .rounded) }

struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.bg1, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
    }
}

extension View {
    func glass(_ r: CGFloat = 22) -> some View {
        self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: r, style: .continuous))
    }
}

struct ChunkyButton: ButtonStyle {
    var color: Color
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(rounded(18, .heavy)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(enabled ? color : Color.gray.opacity(0.4)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Sun (1) and moon (0) tokens.
struct Token: View {
    let value: Int8
    var size: CGFloat
    var body: some View {
        ZStack {
            if value == 1 {
                Circle().fill(RadialGradient(colors: [.yellow, Theme.sun], center: .center, startRadius: 1, endRadius: size / 2))
                    .frame(width: size * 0.62, height: size * 0.62)
                    .shadow(color: Theme.sun.opacity(0.7), radius: size * 0.12)
            } else if value == 0 {
                Crescent().fill(Theme.moon)
                    .frame(width: size * 0.66, height: size * 0.66)
                    .shadow(color: Theme.moon.opacity(0.6), radius: size * 0.1)
            }
        }
    }
}

struct Crescent: Shape {
    func path(in r: CGRect) -> Path {
        let full = Path(ellipseIn: r)
        let cut = Path(ellipseIn: r.offsetBy(dx: r.width * 0.28, dy: -r.height * 0.1).insetBy(dx: r.width * 0.04, dy: r.height * 0.04))
        return full.subtracting(cut)
    }
}
