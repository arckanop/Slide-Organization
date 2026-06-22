import SwiftUI

extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    var hexString: String {
        let resolved = resolve(in: EnvironmentValues())
        let r = Int((resolved.red * 255).rounded())
        let g = Int((resolved.green * 255).rounded())
        let b = Int((resolved.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

enum ClassColorPalette {
    static let hexValues = [
        "#EF4444", "#F97316", "#F59E0B", "#84CC16",
        "#22C55E", "#10B981", "#06B6D4", "#3B82F6",
        "#6366F1", "#8B5CF6", "#D946EF", "#EC4899",
    ]
}
