//
//  SongMetadata.swift
//  OpenStream
//
//  Stores extended metadata in a JSON sidecar file next to each song.
//  This allows metadata to travel with the song file and be updated
//  from remote sources or user edits.
//

import Foundation

/// Extended metadata stored as JSON sidecar next to each song file.
/// Allows for synced lyrics, remote artwork URLs, user modifications, etc.
struct SongMetadata: Codable {
    /// Unique identifier matching the LibrarySong ID
    var songId: UUID
    
    // MARK: - Basic Metadata
    var title: String
    var artist: String
    var album: String?
    var albumArtist: String?
    var genre: String?
    var composer: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: TimeInterval
    
    // MARK: - Extended Content
    /// Full lyrics with line breaks
    var lyrics: String?
    /// Synced lyrics format: "00:12 First line\n00:15 Second line\n..."
    /// Timestamp in MM:SS.mmm format
    var syncedLyrics: String?
    /// Song description or comment
    var songDescription: String?
    
    // MARK: - Artwork & Media
    /// Local path to cached artwork
    var artworkPath: String?
    /// Remote URL for artwork (for future fetching)
    var remoteArtworkURL: URL?
    
    // MARK: - User Modifications
    /// Tracks if metadata was user-edited
    var isUserEdited: Bool = false
    /// Timestamp of last modification
    var lastModified: Date = Date()
    
    // MARK: - Remote Sync
    /// ID from remote service (e.g., Spotify, Apple Music)
    var remoteId: String?
    /// Source of the metadata (local, spotify, apple_music, etc)
    var metadataSource: String = "local"
    
    init(from song: LibrarySong) {
        self.songId = song.id
        self.title = song.title
        self.artist = song.artist
        self.album = song.album
        self.albumArtist = song.albumArtist
        self.genre = song.genre
        self.composer = song.composer
        self.year = song.year
        self.trackNumber = song.trackNumber
        self.discNumber = song.discNumber
        self.duration = song.duration
        self.lyrics = song.lyrics
        self.songDescription = song.songDescription
        self.artworkPath = song.artworkPath
    }
}
