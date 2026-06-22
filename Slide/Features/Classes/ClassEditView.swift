import SwiftUI
import SwiftData

struct ClassEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let classSubject: ClassSubject?

    @State private var name: String
    @State private var colorHex: String
    @State private var teacher: String
    @State private var note: String

    init(classSubject: ClassSubject? = nil) {
        self.classSubject = classSubject
        _name = State(initialValue: classSubject?.name ?? "")
        _colorHex = State(initialValue: classSubject?.colorHex ?? ClassColorPalette.hexValues.randomElement()!)
        _teacher = State(initialValue: classSubject?.teacher ?? "")
        _note = State(initialValue: classSubject?.note ?? "")
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Class") {
                    TextField("Name", text: $name)
                    TextField("Teacher (optional)", text: $teacher)
                }
                Section("Color") {
                    colorGrid
                }
                Section("Note") {
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(classSubject == nil ? "New Class" : "Edit Class")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isNameValid)
                }
            }
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(ClassColorPalette.hexValues, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 32, height: 32)
                    .overlay {
                        if hex == colorHex {
                            Circle().strokeBorder(.primary, lineWidth: 2)
                                .padding(2)
                        }
                    }
                    .onTapGesture { colorHex = hex }
                    .accessibilityLabel(hex)
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTeacher = teacher.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = classSubject {
            existing.name = trimmedName
            existing.colorHex = colorHex
            existing.teacher = trimmedTeacher.isEmpty ? nil : trimmedTeacher
            existing.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            let new = ClassSubject(
                name: trimmedName,
                colorHex: colorHex,
                teacher: trimmedTeacher.isEmpty ? nil : trimmedTeacher,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    ClassEditView()
        .modelContainer(for: [ClassSubject.self], inMemory: true)
}
