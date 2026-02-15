//
//  PlaybackController.swift
//  OpenStream
//
//  Shared playback state using AVPlayer. Drives mini player and full player UI.
//  Designed for music now; can later support podcasts and audiobooks.
//

import Foundation
import AVFoundation

@Observable
@MainActor
final class PlaybackController {
    static let shared = PlaybackController()

    private var player: AVPlayer?
    private var timeObserver: Any?
    private let library = SongLibrary.shared

    /// Currently loaded track (nil when nothing selected).
    private(set) var currentItem: LibrarySong?

    /// Playback position in seconds.
    private(set) var currentTime: TimeInterval = 0

    /// Duration of current item in seconds (from metadata or player).
    private(set) var duration: TimeInterval = 0

    /// True when the player is playing.
    private(set) var isPlaying: Bool = false

    private init() {}

    // MARK: - Audio session (iOS)

    /// On iOS, AVPlayer has no sound until the audio session is set to playback.
    private func configureAudioSessionIfNeeded() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            // Session may already be configured; continue playback anyway
        }
        #endif
    }

    // MARK: - Playback

    /// Start playing a song (replaces current item).
    func play(_ song: LibrarySong) {
        configureAudioSessionIfNeeded()
        let url = library.getFileURL(for: song)
        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
            addTimeObserver()
            addEndOfPlaybackObserver()
        } else {
            player?.replaceCurrentItem(with: item)
        }
        currentItem = song
        duration = song.duration > 0 ? song.duration : 0
        currentTime = 0
        player?.play()
        isPlaying = true
        observeDuration(from: item)
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func playPause() {
        guard currentItem != nil else { return }
        if isPlaying {
            pause()
        } else {
            player?.play()
            isPlaying = true
        }
    }

    func seek(to time: TimeInterval) {
        guard time.isFinite, time >= 0 else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        currentTime = time
    }

    /// Play previous track in library order (by import date).
    func playPrevious() {
        playNeighbor(offset: -1)
    }

    /// Play next track in library order.
    func playNext() {
        playNeighbor(offset: 1)
    }

    private func playNeighbor(offset: Int) {
        let songs = library.songs
        guard let current = currentItem, !songs.isEmpty else {
            if offset > 0 { isPlaying = false }
            return
        }
        guard let index = songs.firstIndex(where: { $0.id == current.id }) else {
            if offset > 0 { isPlaying = false }
            return
        }
        let nextIndex = index + offset
        guard songs.indices.contains(nextIndex) else {
            if offset > 0 { isPlaying = false }
            return
        }
        play(songs[nextIndex])
    }

    // MARK: - Observers

    private func addTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }

    private func observeDuration(from item: AVPlayerItem) {
        guard duration <= 0 else { return }
        Task { @MainActor in
            do {
                let loadedDuration = try await item.asset.load(.duration)
                let seconds = CMTimeGetSeconds(loadedDuration)
                if seconds.isFinite, seconds > 0 {
                    self.duration = seconds
                }
            } catch {
                // Keep duration from metadata or 0
            }
        }
    }

    private func addEndOfPlaybackObserver() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self,
                      let ended = note.object as? AVPlayerItem,
                      ended === self.player?.currentItem else { return }
                self.playNext()
            }
        }
    }
}
