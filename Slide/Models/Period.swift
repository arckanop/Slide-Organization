import SwiftData
import Foundation

/// One row of the school bell schedule, shared across all weekdays.
@Model
final class Period {
    var id: UUID = UUID()
    var orderIndex: Int               // 1, 2, 3... display order
    var startMinutes: Int             // minutes from midnight (08:30 -> 510)
    var endMinutes: Int               // exclusive
    var label: String                 // "คาบ 1" / "Period 1" / "Lunch"
    var isBreak: Bool = false         // lunch/assembly => not assignable

    init(orderIndex: Int, startMinutes: Int, endMinutes: Int, label: String, isBreak: Bool = false) {
        self.orderIndex = orderIndex; self.startMinutes = startMinutes
        self.endMinutes = endMinutes; self.label = label; self.isBreak = isBreak
    }
}
