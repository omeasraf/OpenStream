//
//  SongRow.swift
//  OpenStream
//

import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct SongRow: View {
    let song: LibrarySong
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            artworkView
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var artworkView: some View {
        Group {
            if let data = song.artwork {
                #if os(iOS)
                    if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholderArtwork
                    }
                #else
                    if let nsImage = NSImage(data: data) {
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
        .frame(width: 50, height: 50)
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
