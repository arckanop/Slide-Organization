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
/// Every accessor falls back to the matching `AppSettingsDefault` member through
/// `value(forKey:default:)` below, the same default each `@AppStorage` declaration
/// is seeded with — so there's one place a default can live, not two.
enum AppStorageSnapshot {
    static var imageFormat: ImageFormat {
        guard let raw = UserDefaults.standard.string(forKey: AppSettingsKey.imageFormat),
              let format = ImageFormat(rawValue: raw)
        else { return AppSettingsDefault.imageFormat }
        return format
    }

    static var jpegQuality: Double {
        value(forKey: AppSettingsKey.jpegQuality, default: AppSettingsDefault.jpegQuality) {
            UserDefaults.standard.double(forKey: $0)
        }
    }

    static var maxLongEdge: Int {
        value(forKey: AppSettingsKey.maxLongEdge, default: AppSettingsDefault.maxLongEdge) {
            UserDefaults.standard.integer(forKey: $0)
        }
    }

    static var promptDeleteAfterImport: Bool {
        value(forKey: AppSettingsKey.promptDeleteAfterImport, default: AppSettingsDefault.promptDeleteAfterImport) {
            UserDefaults.standard.bool(forKey: $0)
        }
    }

    /// `UserDefaults`'s scalar accessors (`.double`, `.integer`, `.bool`) return
    /// Swift's zero-value when a key is unset, which would silently mask a
    /// non-zero default. Checking `object(forKey:)` first makes the fallback
    /// explicit for every accessor above, instead of only the ones that
    /// happened to need a non-zero default.
    private static func value<T>(forKey key: String, default defaultValue: T, read: (String) -> T) -> T {
        UserDefaults.standard.object(forKey: key) == nil ? defaultValue : read(key)
    }
}
