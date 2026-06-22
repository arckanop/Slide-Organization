import Foundation

struct CurrentClassResolver {
    /// Returns (subject, period) for `now`, or nil if it's a break / free / off-hours.
    func current(at now: Date,
                 periods: [Period],
                 cells: [TimetableCell],
                 calendar: Calendar = .current) -> (subject: ClassSubject, period: Period)? {
        let weekday = calendar.component(.weekday, from: now)
        let mins = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        guard let period = periods.first(where: { !$0.isBreak && $0.startMinutes <= mins && mins < $0.endMinutes })
        else { return nil }
        guard let subject = cells.first(where: { $0.weekday == weekday && $0.period?.id == period.id })?.subject
        else { return nil }
        return (subject, period)
    }
}
