//
//  HomeView.swift
//  OpenStream
//

import SwiftUI

struct HomeView: View {
    private var library: SongLibrary { SongLibrary.shared }
    private var playback: PlaybackController { PlaybackController.shared }

    var body: some View {
        Group {
            if library.songs.isEmpty {
                ContentUnavailableView(
                    "No music yet",
                    systemImage: "music.note.list",
                    description: Text(
                        "Import songs in Settings to get started."
                    )
                )
            } else {
                List(library.songs) { song in
                    SongRow(
                        song: song,
                        isCurrent: playback.currentItem?.id == song.id
                    )
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
        .navigationTitle("Home")
    }
}

#Preview {
    HomeView()
}
