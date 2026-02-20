//
//  AlbumView.swift
//  OpenStream
//

import UIKit
import SwiftUI

struct AlbumView: View {
    private var playback: PlaybackController { PlaybackController.shared }
    
    let album: Album

    var body: some View {
        VStack(spacing: 0) {
            // Album header
            VStack(spacing: 16) {
                if let artworkPath = album.artworkPath {
                    Image(uiImage: UIImage(contentsOfFile: artworkPath) ?? UIImage())
                        .resizable()
                        .scaledToFill()
                        .frame(height: 250)
                        .clipped()
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 100))
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                        .background(.gray.opacity(0.3))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(album.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let artist = album.artist {
                        Text(artist)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        Text("\(album.songCount) song\(album.songCount == 1 ? "" : "s")")
                            .font(.caption)
                        
                        if let year = album.year {
                            Text("\(year)")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(.background)
            
            // Songs list
            if album.songs.isEmpty {
                ContentUnavailableView(
                    "No songs",
                    systemImage: "music.note.list",
                    description: Text("This album has no songs.")
                )
            } else {
                List(album.songs) { song in
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
        .navigationTitle("Album")
        .navigationBarTitleDisplayMode(.inline)
    }
}

