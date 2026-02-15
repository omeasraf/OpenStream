//
//  ContentView.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/14/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
            #if os(iOS)
                .padding(.bottom, 60)
            #else
                .padding(.bottom, 5)
            #endif
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if SongLibrary.shared.modelContext == nil {
                SongLibrary.shared.setModelContext(modelContext)
            }
        }
    #if os(iOS)
        .fullScreenCover(isPresented: $isMiniPlayerExpanded) {
            OpenPlayerView(isPresented: $isMiniPlayerExpanded)
        }
    #else
        .sheet(isPresented: $isMiniPlayerExpanded) {
            OpenPlayerView(isPresented: $isMiniPlayerExpanded)
        }
    #endif
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
    private var library: SongLibrary { SongLibrary.shared }
    private var playback: PlaybackController { PlaybackController.shared }

    var body: some View {
        Group {
            if library.songs.isEmpty {
                ContentUnavailableView(
                    "No music yet",
                    systemImage: "music.note.list",
                    description: Text("Import songs in Settings to get started.")
                )
            } else {
                List(library.songs) { song in
                    SongRow(song: song, isCurrent: playback.currentItem?.id == song.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playback.play(song)
                        }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .navigationTitle("Library")
    }
}

#Preview {
    ContentView()
}
