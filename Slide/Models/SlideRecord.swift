import SwiftData
import Foundation

@Model
final class Slide {
    var id: UUID = UUID()
    var imageFileName: String         // "<uuid>.heic" or ".jpg"
    var thumbnailFileName: String?
    var captureDate: Date = Date()    // user-editable
    var sessionTitle: String?
    var ocrText: String?
    var note: String?
    var subject: ClassSubject?
    var createdAt: Date = Date()

    init(imageFileName: String, subject: ClassSubject?, captureDate: Date = Date()) {
        self.imageFileName = imageFileName; self.subject = subject; self.captureDate = captureDate
    }
}
