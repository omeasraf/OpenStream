//
//  OpenStreamApp.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/14/26.
//

import SwiftUI
import SwiftData

@main
struct OpenStreamApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LibrarySong.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
