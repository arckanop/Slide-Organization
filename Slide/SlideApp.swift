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
        let configuration = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        DefaultData.seedPeriodsIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
