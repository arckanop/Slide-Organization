import SwiftUI
import SwiftData

struct ClassesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClassSubject.name) private var classes: [ClassSubject]
    @State private var showingNewClass = false
    @State private var editingClass: ClassSubject?

    var body: some View {
        NavigationStack {
            Group {
                if classes.isEmpty {
                    ContentUnavailableView(
                        "No Classes Yet",
                        systemImage: "books.vertical",
                        description: Text("Add a class to start organizing your slides.")
                    )
                } else {
                    List {
                        ForEach(classes) { subject in
                            NavigationLink(value: subject) {
                                ClassRow(subject: subject)
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) { delete(subject) }
                                Button("Edit") { editingClass = subject }.tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Classes")
            .navigationDestination(for: ClassSubject.self) { subject in
                ClassDetailView(classSubject: subject)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewClass = true
                    } label: {
                        Label("Add Class", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewClass) {
                ClassEditView()
            }
            .sheet(item: $editingClass) { subject in
                ClassEditView(classSubject: subject)
            }
        }
    }

    private func delete(_ subject: ClassSubject) {
        let filesToDelete = subject.slides.map { ($0.imageFileName, $0.thumbnailFileName) }
        context.delete(subject)
        try? context.save()
        for (image, thumb) in filesToDelete {
            FileStore.shared.delete(imageFileName: image, thumbnailFileName: thumb)
        }
    }
}

private struct ClassRow: View {
    let subject: ClassSubject

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: subject.colorHex))
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(subject.name).font(.headline)
                if let teacher = subject.teacher, !teacher.isEmpty {
                    Text(teacher).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(subject.slides.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let last = subject.slides.map(\.captureDate).max() {
                    Text(last, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ClassesListView()
        .modelContainer(for: [ClassSubject.self, Slide.self], inMemory: true)
}
