//
//  LibrarySong.swift
//  OpenStream
//
//  SwiftData model for a song in the user's library.
//  Holds all standard audio metadata (title, artist, lyrics, album, etc.).
//

import Foundation
import SwiftData
import CryptoKit

@Model
final class LibrarySong: Identifiable, Hashable {
    // MARK: - Required (identity & storage)
    @Attribute(.unique) var id: UUID
    var fileName: String
    var fileHash: String
    var importedDate: Date

    // MARK: - Core display
    var title: String
    var artist: String
    var duration: TimeInterval

    // MARK: - Extended metadata (optional)
    var lyrics: String?
    var album: String?
    var albumArtist: String?
    var genre: String?
    /// Comment or description from the file (ID3 comment, etc.)
    var songDescription: String?
    var trackNumber: Int?
    var discNumber: Int?
    var year: Int?
    var composer: String?
    /// Cover/artwork image data (JPEG/PNG)
    var artwork: Data?

    init(
        title: String,
        artist: String,
        fileName: String,
        fileHash: String,
        duration: TimeInterval = 0,
        lyrics: String? = nil,
        album: String? = nil,
        albumArtist: String? = nil,
        genre: String? = nil,
        songDescription: String? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        composer: String? = nil,
        artwork: Data? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.artist = artist
        self.fileName = fileName
        self.fileHash = fileHash
        self.importedDate = Date()
        self.duration = duration
        self.lyrics = lyrics
        self.album = album
        self.albumArtist = albumArtist
        self.genre = genre
        self.songDescription = songDescription
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.year = year
        self.composer = composer
        self.artwork = artwork
    }

    static func == (lhs: LibrarySong, rhs: LibrarySong) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Hashing

extension Data {
    func sha256() -> String {
        let hash = SHA256.hash(data: self)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
