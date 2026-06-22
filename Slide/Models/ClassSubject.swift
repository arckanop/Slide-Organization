import SwiftData
import Foundation

@Model
final class ClassSubject {
    var id: UUID = UUID()
    var name: String                  // "เคมี ม.5"
    var colorHex: String              // "#3B82F6"
    var teacher: String?
    var note: String?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Slide.subject)
    var slides: [Slide] = []
    @Relationship(deleteRule: .nullify, inverse: \TimetableCell.subject)
    var timetableCells: [TimetableCell] = []

    init(name: String, colorHex: String, teacher: String? = nil, note: String? = nil) {
        self.name = name; self.colorHex = colorHex; self.teacher = teacher; self.note = note
    }
}
