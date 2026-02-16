//
//  OpenPlayerView.swift
//  OpenStream
//

import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct OpenPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private var playback: PlaybackController { PlaybackController.shared }

    var body: some View {
        VStack(spacing: 20) {
            // Drag indicator with its own gesture for better hit area
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .overlay(
                    Color.clear
                        .frame(width: 60, height: 30)
                        .contentShape(Rectangle())
                        .gesture(dragGesture)
                )

            Spacer()

            artworkView
                .frame(width: 300, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(
                    isDragging ? max(0.9, 1.0 - (dragOffset / 1000)) : 1.0
                )

            VStack(spacing: 4) {
                Text(playback.currentItem?.title ?? "No track")
                    .font(.title2.bold())
                Text(playback.currentItem?.artist ?? "—")
                    .foregroundStyle(.secondary)
            }

            progressSection

            HStack(spacing: 50) {
                Button {
                    playback.playPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .disabled(playback.currentItem == nil)

                Button {
                    playback.playPause()
                } label: {
                    Image(
                        systemName: playback.isPlaying
                            ? "pause.fill" : "play.fill"
                    )
                    .font(.system(size: 40))
                }
                .buttonStyle(.plain)
                .disabled(playback.currentItem == nil)

                Button {
                    playback.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .disabled(playback.currentItem == nil)
            }
            .padding(.top, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .ignoresSafeArea(.container, edges: .bottom)
        .offset(y: dragOffset)
        .animation(
            .interactiveSpring(response: 0.4, dampingFraction: 0.8),
            value: dragOffset
        )
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                // Only allow dragging down
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                isDragging = false
                // Dismiss if dragged down far enough or with enough velocity
                if value.translation.height > 150
                    || value.predictedEndTranslation.height > 200
                {
                    dismiss()
                } else {
                    // Spring back
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
                    {
                        dragOffset = 0
                    }
                }
            }
    }

    @ViewBuilder
    private var artworkView: some View {
        Group {
            if let song = playback.currentItem, let data = song.artwork {
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
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.gray.opacity(0.3))
            .overlay(
                Image(systemName: "music.note").font(.system(size: 80))
                    .foregroundStyle(.secondary)
            )
    }

    private var progressSection: some View {
        let duration = max(playback.duration, 0.001)
        let progress =
            duration > 0 ? min(max(playback.currentTime / duration, 0), 1) : 0.0

        return VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { progress },
                    set: { newValue in
                        playback.seek(to: newValue * duration)
                    }
                ),
                in: 0...1
            )
            .padding(.horizontal, 24)

            HStack {
                Text(formatTime(playback.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 8)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}

#Preview {
    OpenPlayerView()
}
