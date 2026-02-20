//
//  NowPlayingArtwork.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/19/26.
//

import SwiftUI

struct NowPlayingArtworkView: View {
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGFloat = 0
    var playback: PlaybackController

    private var artworkImage: Image {
        if let song = playback.currentItem,
           let path = song.artworkPath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        {
            #if os(iOS)
                if let uiImage = UIImage(data: data) {
                    return Image(uiImage: uiImage)
                }
            #else
                if let nsImage = NSImage(data: data) {
                    return Image(nsImage: nsImage)
                }
            #endif
        }
        return Image(systemName: "music.note")
    }

    var body: some View {
        artworkImage
            .resizable()
            .scaledToFill()
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipped()
            .scaleEffect(
                playback.isPlaying ? (isDragging ? 0.98 : 1.1) : (isDragging ? 0.95 : 1.0)
            )
            .animation(
                .interactiveSpring(response: 0.5, dampingFraction: 0.86, blendDuration: 0.17),
                value: playback.isPlaying || isDragging
            )
            .transition(.identity)
            .padding(24)
    }
}
