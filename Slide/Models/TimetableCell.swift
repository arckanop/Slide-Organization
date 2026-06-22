import SwiftData
import Foundation

/// Assigns a subject to a (weekday, period) cell of the weekly grid.
@Model
final class TimetableCell {
    var id: UUID = UUID()
    var weekday: Int                  // Calendar weekday: 1=Sun ... 7=Sat
    var period: Period?
    var subject: ClassSubject?

    init(weekday: Int, period: Period?, subject: ClassSubject?) {
        self.weekday = weekday; self.period = period; self.subject = subject
    }
}
