import Foundation

enum ImageFormat: String, CaseIterable, Identifiable {
    case heicOriginal
    case jpegCompressed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heicOriginal: return "HEIC (full resolution)"
        case .jpegCompressed: return "JPEG (compressed)"
        }
    }
}

/// Thin wrapper around the `@AppStorage` keys used across the app, so every
/// read site shares the same key strings and defaults.
enum AppSettingsKey {
    static let imageFormat = "imageFormat"
    static let jpegQuality = "jpegQuality"
    static let maxLongEdge = "maxLongEdge"
    static let promptDeleteAfterImport = "promptDeleteAfterImport"
    static let visibleWeekdays = "visibleWeekdays"
}

enum AppSettingsDefault {
    static let imageFormat = ImageFormat.heicOriginal
    static let jpegQuality = 0.8
    static let maxLongEdge = 0
    static let promptDeleteAfterImport = true
    /// Calendar weekday values, Mon...Fri = 2...6.
    static let visibleWeekdays = [2, 3, 4, 5, 6]
    static let visibleWeekdaysStorage = "2,3,4,5,6"
}

/// `@AppStorage` only stores scalars, so the visible-weekdays set is persisted
/// as a comma-joined string of Calendar weekday numbers (1=Sun...7=Sat).
enum VisibleWeekdaysCoding {
    static func decode(_ raw: String) -> Set<Int> {
        let values = raw.split(separator: ",").compactMap { Int($0) }
        return values.isEmpty ? Set(AppSettingsDefault.visibleWeekdays) : Set(values)
    }

    static func encode(_ weekdays: Set<Int>) -> String {
        weekdays.sorted().map(String.init).joined(separator: ",")
    }
}

/// Reads the same `UserDefaults` keys `@AppStorage` writes to, for use from
/// non-View code (capture/import pipelines) that can't hold a property wrapper.
enum AppStorageSnapshot {
    static var imageFormat: ImageFormat {
        guard let raw = UserDefaults.standard.string(forKey: AppSettingsKey.imageFormat),
              let format = ImageFormat(rawValue: raw)
        else { return AppSettingsDefault.imageFormat }
        return format
    }

    static var jpegQuality: Double {
        UserDefaults.standard.object(forKey: AppSettingsKey.jpegQuality) == nil
            ? AppSettingsDefault.jpegQuality
            : UserDefaults.standard.double(forKey: AppSettingsKey.jpegQuality)
    }

    static var maxLongEdge: Int {
        UserDefaults.standard.integer(forKey: AppSettingsKey.maxLongEdge)
    }

    static var promptDeleteAfterImport: Bool {
        UserDefaults.standard.object(forKey: AppSettingsKey.promptDeleteAfterImport) == nil
            ? AppSettingsDefault.promptDeleteAfterImport
            : UserDefaults.standard.bool(forKey: AppSettingsKey.promptDeleteAfterImport)
    }
}
