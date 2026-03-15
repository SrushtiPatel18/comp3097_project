import SwiftUI

enum AppTheme {
    // Purple + Blue theme
    static let purple = Color(hex: "#6D28D9")
    static let blue   = Color(hex: "#2563EB")

    static let good   = Color(hex: "#16A34A")
    static let bad    = Color(hex: "#DC2626")

    static let bgGradient = LinearGradient(
        colors: [Color(hex: "#EEF2FF"), Color(hex: "#F5F3FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Rounded fonts (nice + modern, no downloads)
    static let title    = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let body     = Font.system(size: 16, weight: .regular, design: .rounded)
    static let caption  = Font.system(size: 13, weight: .medium, design: .rounded)
}

// Card style helper
extension View {
    func spCard() -> some View {
        self
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.25))
            )
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

// Hex color helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8: (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
