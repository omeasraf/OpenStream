//
//  MainTabView.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/15/26.
//

import SwiftData
import SwiftUI

struct OpenTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isMiniPlayerExpanded = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }

            Tab("Library", systemImage: "music.note.list") {
                Text("Library")
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            IndexingStatusView()
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if SongLibrary.shared.modelContext == nil {
                SongLibrary.shared.setModelContext(modelContext)
            }
        }
        #if os(iOS)
            .fullScreenCover(isPresented: $isMiniPlayerExpanded) {
                OpenPlayerView()
            }
        #else
            .sheet(isPresented: $isMiniPlayerExpanded) {
                OpenPlayerView(isPresented: $isMiniPlayerExpanded)
            }
        #endif
    }
}

#Preview {
    OpenTabView()
}
