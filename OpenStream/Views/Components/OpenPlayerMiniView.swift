//
//  OpenPlayerMiniView.swift
//  OpenStream
//

import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct OpenPlayerMiniView: View {
    private var playback: PlaybackController { PlaybackController.shared }

    var body: some View {
        HStack(spacing: 12) {
            artworkView
            VStack(alignment: .leading, spacing: 2) {
                Text(playback.currentItem?.title ?? "OpenStream")
                    .font(.headline)
                    .lineLimit(1)
                Text(playback.currentItem?.artist ?? "Tap a song to play")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                playback.playPause()
            } label: {
                Image(
                    systemName: playback.isPlaying ? "pause.fill" : "play.fill"
                )
                .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(playback.currentItem == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(radius: 6)
    }

    @ViewBuilder
    private var artworkView: some View {
        Group {
            if let song = playback.currentItem, let artworkPath = song.artworkPath {
                #if os(iOS)
                    if let imageData = try? Data(contentsOf: URL(fileURLWithPath: artworkPath)),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholderArtwork
                    }
                #else
                    if let imageData = try? Data(contentsOf: URL(fileURLWithPath: artworkPath)),
                       let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholderArtwork
                    }
                #endif
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 35, height: 35)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.gray.opacity(0.3))
            .overlay(
                Image(systemName: "music.note").foregroundStyle(.secondary)
            )
    }
}

#Preview {
    OpenPlayerMiniView()
}
