import SwiftUI
import PhotosUI
import SwiftData

/// Multi-select import from the photo library. Works on every platform;
/// deleting the originals afterward (Photos write access) is iOS/iPadOS-only.
struct ImageImporter: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClassSubject.name) private var classes: [ClassSubject]

    @State private var target: ClassSubject?
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var sessionTitle = ""
    @State private var batchDate = Date()
    @State private var isImporting = false
    @State private var importedCount = 0
    @State private var saveFailureMessage: String?
    @State private var showingSaveFailureAlert = false

    #if os(iOS)
    @State private var showingDeletePrompt = false
    @State private var importedAssetIDs: [String] = []
    #endif

    init(defaultTarget: ClassSubject? = nil) {
        _target = State(initialValue: defaultTarget)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Class") {
                    Picker("Class", selection: $target) {
                        Text("Choose a class").tag(Optional<ClassSubject>.none)
                        ForEach(classes) { subject in
                            Text(subject.name).tag(Optional(subject))
                        }
                    }
                }
                Section("Photos") {
                    PhotosPicker(selection: $selectedItems, matching: .images, photoLibrary: .shared()) {
                        Label(selectedItems.isEmpty ? "Select Photos" : "\(selectedItems.count) Selected",
                              systemImage: "photo.on.rectangle.angled")
                    }
                }
                Section("Session (optional)") {
                    TextField("Title", text: $sessionTitle)
                    DatePicker("Date", selection: $batchDate)
                }
            }
            .navigationTitle("Import from Photos")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { Task { await importSelected() } }
                        .disabled(target == nil || selectedItems.isEmpty || isImporting)
                }
            }
            .overlay {
                if isImporting {
                    ProgressView("Importing \(importedCount)/\(selectedItems.count)")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            #if os(iOS)
            .alert("Delete Original Photos?", isPresented: $showingDeletePrompt) {
                Button("Keep Originals", role: .cancel) { dismiss() }
                Button("Delete Originals", role: .destructive) {
                    Task {
                        try? await PhotoLibrary.deleteAssets(localIdentifiers: importedAssetIDs)
                        dismiss()
                    }
                }
            } message: {
                Text("Remove the \(importedAssetIDs.count) imported photo(s) from your photo library? Your in-app copies are kept either way.")
            }
            #endif
            .alert("Some Photos Couldn't Be Saved", isPresented: $showingSaveFailureAlert) {
                Button("OK") { proceedAfterImport() }
            } message: {
                Text(saveFailureMessage ?? "")
            }
        }
    }

    private func importSelected() async {
        guard let target else { return }
        isImporting = true
        importedCount = 0
        var pages: [Data] = []
        var assetIDs: [String] = []
        var loadFailedCount = 0

        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self) {
                pages.append(data)
                if let id = item.itemIdentifier { assetIDs.append(id) }
            } else {
                loadFailedCount += 1
            }
            importedCount += 1
        }

        let title = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = CaptureFlow.commit(
            pages: pages,
            to: target,
            sessionTitle: title.isEmpty ? nil : title,
            captureDate: batchDate,
            context: context
        )

        isImporting = false
        #if os(iOS)
        importedAssetIDs = assetIDs
        #endif

        let totalFailed = result.failedCount + loadFailedCount
        if totalFailed > 0 {
            saveFailureMessage = "Imported \(result.savedCount) of \(selectedItems.count) photo(s). \(totalFailed) failed to import."
            showingSaveFailureAlert = true
        } else {
            proceedAfterImport()
        }
    }

    private func proceedAfterImport() {
        #if os(iOS)
        if AppStorageSnapshot.promptDeleteAfterImport, !importedAssetIDs.isEmpty {
            showingDeletePrompt = true
        } else {
            dismiss()
        }
        #else
        dismiss()
        #endif
    }
}
