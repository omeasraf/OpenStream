//
//  HomeView.swift
//  OpenStream
//

import SwiftUI

struct HomeView: View {
    private var library: SongLibrary { SongLibrary.shared }
    private var playback: PlaybackController { PlaybackController.shared }
    
    @State private var showAlbums = true

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
                VStack {
                    // Toggle between albums and songs view
                    Picker("View", selection: $showAlbums) {
                        Text("Albums").tag(true)
                        Text("Songs").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Albums view
                    if showAlbums {
                        if library.albums.isEmpty {
                            ContentUnavailableView(
                                "No albums",
                                systemImage: "music.note.house",
                                description: Text("Albums will appear as you add songs.")
                            )
                        } else {
                            List(library.albums) { album in
                                NavigationLink(destination: AlbumView(album: album)) {
                                    HStack(spacing: 12) {
                                        // Album artwork
                                        if let artworkPath = album.artworkPath {
                                            Image(uiImage: UIImage(contentsOfFile: artworkPath) ?? UIImage())
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 50, height: 50)
                                                .cornerRadius(4)
                                        } else {
                                            Image(systemName: "music.note")
                                                .frame(width: 50, height: 50)
                                                .background(.gray.opacity(0.3))
                                                .cornerRadius(4)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(album.name)
                                                .font(.body)
                                                .fontWeight(.semibold)
                                            
                                            Text(album.artist ?? "Unknown Artist")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Text("\(album.songCount) song\(album.songCount == 1 ? "" : "s")")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        
                                        Spacer()
                                        
                                        if let year = album.year {
                                            Text("\(year)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .listStyle(.inset)
                        }
                    } else {
                        // Songs view
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

