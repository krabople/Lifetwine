import SwiftUI
import UIKit

enum LifetwineTheme {
    static let ink = Color(hex: "17212B")
    static let secondaryInk = Color(hex: "5E6873")
    static let canvas = Color(hex: "F5F6F2")
    static let card = Color.white
    static let indigo = Color(hex: "5B68D8")
    static let mint = Color(hex: "58B89C")
    static let amber = Color(hex: "EDA84F")
    static let coral = Color(hex: "EA796B")
    static let lilac = Color(hex: "A379C9")
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var integer: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&integer)
        let red, green, blue, alpha: UInt64
        switch cleaned.count {
        case 3:
            (red, green, blue, alpha) = (
                (integer >> 8) * 17,
                (integer >> 4 & 0xF) * 17,
                (integer & 0xF) * 17,
                255
            )
        case 8:
            (red, green, blue, alpha) = (integer >> 24, integer >> 16 & 0xFF, integer >> 8 & 0xFF, integer & 0xFF)
        default:
            (red, green, blue, alpha) = (integer >> 16, integer >> 8 & 0xFF, integer & 0xFF, 255)
        }
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

extension View {
    func lifetwineCard() -> some View {
        self
            .background(LifetwineTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: LifetwineTheme.ink.opacity(0.055), radius: 14, y: 5)
    }
}

enum Haptics {
    static func logged() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selected() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

