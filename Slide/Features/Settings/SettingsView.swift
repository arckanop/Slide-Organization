import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage(AppSettingsKey.imageFormat) private var imageFormatRaw = AppSettingsDefault.imageFormat.rawValue
    @AppStorage(AppSettingsKey.jpegQuality) private var jpegQuality = AppSettingsDefault.jpegQuality
    @AppStorage(AppSettingsKey.promptDeleteAfterImport) private var promptDeleteAfterImport = AppSettingsDefault.promptDeleteAfterImport

    @State private var showingTimetable = false
    @State private var storageUsedBytes: Int64?

    private var imageFormat: ImageFormat {
        ImageFormat(rawValue: imageFormatRaw) ?? .heicOriginal
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Image Format", selection: Binding(
                        get: { imageFormat },
                        set: { imageFormatRaw = $0.rawValue }
                    )) {
                        ForEach(ImageFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    if imageFormat == .jpegCompressed {
                        VStack(alignment: .leading) {
                            Text("JPEG Quality: \(Int(jpegQuality * 100))%")
                            Slider(value: $jpegQuality, in: 0.4...1.0, step: 0.05)
                        }
                    }
                    Text(formatTradeoffNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Photo Quality")
                }

                Section {
                    Toggle("Prompt to Delete Originals After Import", isOn: $promptDeleteAfterImport)
                    #if !os(iOS)
                    Text("Deleting originals from Photos is available on iPhone/iPad.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #endif
                } header: {
                    Text("Import")
                }

                Section {
                    Button {
                        showingTimetable = true
                    } label: {
                        Label("Edit Timetable", systemImage: "calendar")
                    }
                    NavigationLink {
                        WeekdayVisibilityEditor()
                    } label: {
                        Text("Visible Weekdays")
                    }
                } header: {
                    Text("Timetable")
                }

                Section {
                    LabeledContent("Storage Used", value: storageUsedBytes.map(formattedBytes) ?? "Calculating…")
                } header: {
                    Text("Storage")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                    Text("SlideShelf captures and organizes lecture slide photos by class and time. Fully on-device — no account, no network.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingTimetable) {
                TimetableEditorView()
            }
            .task {
                storageUsedBytes = await Self.calculateStorageUsed()
            }
        }
    }

    private var formatTradeoffNote: String {
        switch imageFormat {
        case .heicOriginal:
            return "Full resolution HEIC — best legibility for slide text, but uses the most storage."
        case .jpegCompressed:
            return "Compressed JPEG — saves storage, but small text may show more compression artifacts."
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    nonisolated private static func calculateStorageUsed() async -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        for dir in [FileStore.shared.slidesDir, FileStore.shared.thumbsDir] {
            if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for url in contents {
                    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        total += Int64(size)
                    }
                }
            }
        }
        return total
    }
}

private struct WeekdayVisibilityEditor: View {
    @AppStorage(AppSettingsKey.visibleWeekdays) private var visibleWeekdaysRaw = AppSettingsDefault.visibleWeekdaysStorage

    var body: some View {
        List {
            ForEach(Weekday.mondayFirstOrder, id: \.self) { weekday in
                let isOn = VisibleWeekdaysCoding.decode(visibleWeekdaysRaw).contains(weekday)
                Toggle(Weekday.shortLabel(forCalendarWeekday: weekday), isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        var set = VisibleWeekdaysCoding.decode(visibleWeekdaysRaw)
                        if newValue { set.insert(weekday) } else { set.remove(weekday) }
                        visibleWeekdaysRaw = VisibleWeekdaysCoding.encode(set)
                    }
                ))
            }
        }
        .navigationTitle("Visible Weekdays")
    }
}

#Preview {
    SettingsView()
}
