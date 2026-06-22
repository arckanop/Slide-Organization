import SwiftData
import Foundation

/// Seeds a sane Thai school bell schedule (คาบ 1-8, 50-minute periods, lunch
/// block) on first launch. Fully editable afterward via the timetable editor.
enum DefaultData {
    static func seedPeriodsIfNeeded(in context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<Period>())
        guard (existing?.isEmpty ?? true) else { return }

        let rows: [(Int, Int, Int, String, Bool)] = [
            (1, 510, 560, "คาบ 1", false),   // 08:30-09:20
            (2, 560, 610, "คาบ 2", false),   // 09:20-10:10
            (3, 610, 660, "คาบ 3", false),   // 10:10-11:00
            (4, 660, 710, "คาบ 4", false),   // 11:00-11:50
            (5, 710, 760, "พักกลางวัน", true), // 11:50-12:40 lunch
            (6, 760, 810, "คาบ 5", false),   // 12:40-13:30
            (7, 810, 860, "คาบ 6", false),   // 13:30-14:20
            (8, 860, 910, "คาบ 7", false),   // 14:20-15:10
            (9, 910, 960, "คาบ 8", false),   // 15:10-16:00
        ]

        for (order, start, end, label, isBreak) in rows {
            context.insert(Period(orderIndex: order, startMinutes: start, endMinutes: end, label: label, isBreak: isBreak))
        }
        try? context.save()
    }
}
