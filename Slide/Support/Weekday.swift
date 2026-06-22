import Foundation

/// Single source of truth for the Calendar-weekday <-> Monday-first-display
/// mapping, to avoid the off-by-one bug that's easy to introduce otherwise.
enum Weekday {
    /// Calendar weekday values (1=Sun...7=Sat), in Monday-first display order.
    static let mondayFirstOrder = [2, 3, 4, 5, 6, 7, 1]

    /// `Calendar.shortWeekdaySymbols`/`weekdaySymbols` are always indexed with
    /// Sunday at 0, independent of locale — so index by `weekday - 1` directly.
    static func shortLabel(forCalendarWeekday weekday: Int, calendar: Calendar = .current) -> String {
        let symbols = calendar.shortWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1]
    }
}
