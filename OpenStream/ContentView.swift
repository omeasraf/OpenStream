//
//  ContentView.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/14/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isMiniPlayerExpanded = false
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .safeAreaInset(edge: .bottom) {
            OpenPlayerMiniView(onExpand: { isMiniPlayerExpanded = true })
                .padding(.horizontal)
                .padding(.bottom, 60)
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $isMiniPlayerExpanded) {
            OpenPlayerView(isPresented: $isMiniPlayerExpanded)
        }
    }
}


// Placeholder tab screens
struct SearchView: View {
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "magnifyingglass").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Search").font(.largeTitle.bold())
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.background)
    }
}
struct LibraryView: View {
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "music.note.list").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Library").font(.largeTitle.bold())
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.background)
    }
}
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "gearshape").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Settings").font(.largeTitle.bold())
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.background)
    }
}

#Preview {
    ContentView()
}
