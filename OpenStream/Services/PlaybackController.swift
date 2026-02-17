//
//  PlaybackController.swift
//  OpenStream
//

import AVFoundation
import Foundation
import MediaPlayer
import UIKit

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

    private init() {
        setupRemoteCommands()
    }

    // MARK: - Remote Commands & Now Playing

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.isPlaying = true
            self?.updateNowPlaying()
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.isPlaying = false
            self?.updateNowPlaying()
            return .success
        }

        // Skip forward (next track)
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            self?.updateNowPlaying()
            return .success
        }

        // Skip backward (previous track)
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            self?.updateNowPlaying()
            return .success
        }

        // Seek forward/backward
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            let newTime = self.currentTime + 15
            self.seek(to: newTime)
            self.updateNowPlaying()
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            let newTime = max(0, self.currentTime - 15)
            self.seek(to: newTime)
            self.updateNowPlaying()
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let song = currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]

        // Add artwork if available
        if let artworkPath = song.artworkPath, let image = UIImage(contentsOfFile: artworkPath) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Audio session (iOS)

    /// On iOS, AVPlayer has no sound until the audio session is set to playback.
    private func configureAudioSessionIfNeeded() {
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(
                    .playback,
                    mode: .default,
                    options: [.defaultToSpeaker, AVAudioSession.CategoryOptions.allowBluetoothHFP]
                )
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
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func playPause() {
        guard currentItem != nil else { return }
        if isPlaying {
            pause()
        } else {
            player?.play()
            isPlaying = true
            updateNowPlaying()
        }
    }

    func seek(to time: TimeInterval) {
        guard time.isFinite, time >= 0 else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        currentTime = time
        updateNowPlaying()
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
        guard let index = songs.firstIndex(where: { $0.id == current.id })
        else {
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
        // Use an inline @Sendable closure and hop to the MainActor for updates.
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
            }
        })
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
        ) { note in
            let ended = note.object as? AVPlayerItem
            Task { @MainActor [weak self] in
                guard let self = self,
                      let ended
                else { return }
                if ended === self.player?.currentItem {
                    self.playNext()
                }
            }
        }
    }
}

