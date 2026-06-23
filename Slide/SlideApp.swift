//
//  SlideApp.swift
//  Slide
//
//  Created by Kanop Sutharomna on 22/06/2026.
//

import SwiftUI
import SwiftData

@main
struct SlideApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([ClassSubject.self, Slide.self, Period.self, TimetableCell.self])
        container = Self.makeContainer(schema: schema)
        DefaultData.seedPeriodsIfNeeded(in: container.mainContext)
    }

    /// A corrupted on-disk store shouldn't be an unrecoverable crash for a
    /// single-user, on-device app: quarantine it and start fresh rather than
    /// taking down the whole app on every future launch.
    private static func makeContainer(schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("ModelContainer creation failed (\(error)); quarantining store and retrying.")
            quarantineStore(at: configuration.url)
            if let recovered = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)]) {
                return recovered
            }

            print("Retry after quarantine failed; falling back to an in-memory store.")
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let fallback = try? ModelContainer(for: schema, configurations: [inMemory]) else {
                fatalError("Failed to create even an in-memory ModelContainer: \(error)")
            }
            return fallback
        }
    }

    private static func quarantineStore(at url: URL) {
        let fm = FileManager.default
        let suffix = Int(Date().timeIntervalSince1970)
        for path in [url.path, url.path + "-wal", url.path + "-shm"] {
            guard fm.fileExists(atPath: path) else { continue }
            try? fm.moveItem(atPath: path, toPath: "\(path).corrupt-\(suffix)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
