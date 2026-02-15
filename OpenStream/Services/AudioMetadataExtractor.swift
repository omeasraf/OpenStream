//
//  AudioMetadataExtractor.swift
//  OpenStream
//
//  Extracts metadata from audio files using AVFoundation.
//  Supports MP3 (ID3), M4A/AAC (iTunes), FLAC, WAV, and other formats
//  the system can read. Provides title, artist, lyrics, album, genre,
//  description, artwork, and other standard fields.
//

import Foundation
import AVFoundation

/// All metadata extracted from an audio file (AVFoundation).
struct ExtractedAudioMetadata: Sendable {
    var title: String
    var artist: String
    var duration: TimeInterval
    var lyrics: String?
    var album: String?
    var albumArtist: String?
    var genre: String?
    var songDescription: String?
    var trackNumber: Int?
    var discNumber: Int?
    var year: Int?
    var composer: String?
    var artwork: Data?
}

/// Extracts metadata using AVFoundation (supports major formats and full metadata).
enum AudioMetadataExtractor: Sendable {

    static func extract(from url: URL) async -> ExtractedAudioMetadata {
        let asset = AVURLAsset(url: url)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent

        let duration = await loadDuration(from: asset)
        var allMetadata = asset.commonMetadata
        for format in asset.availableMetadataFormats {
            allMetadata.append(contentsOf: asset.metadata(forFormat: format))
        }

        var title = fallbackTitle
        var artist = "Unknown Artist"
        var lyrics: String?
        var album: String?
        var albumArtist: String?
        var genre: String?
        var songDescription: String?
        var trackNumber: Int?
        var discNumber: Int?
        var year: Int?
        var composer: String?
        var artwork: Data?

        for item in allMetadata {
            guard let key = item.commonKey else {
                // Format-specific key (e.g. ID3, iTunes) – try identifier
                if let id = item.identifier?.rawValue {
                    if id.contains("lyrics") || id.contains("Lyrics") {
                        lyrics = item.stringValue ?? lyrics
                    } else if id.contains("comment") || id.contains("Comment") || id.contains("description") {
                        songDescription = item.stringValue ?? songDescription
                    } else if id.contains("year") || id.contains("Year") || id.contains("date") {
                        year = item.numberValue?.intValue ?? item.stringValue.flatMap(parseYear) ?? year
                    } else if id.contains("track") || id.contains("Track") {
                        trackNumber = item.numberValue?.intValue ?? item.stringValue.flatMap(parseTrackNumber) ?? trackNumber
                    } else if id.contains("disc") || id.contains("Disc") {
                        discNumber = item.numberValue?.intValue ?? discNumber
                    }
                }
                continue
            }

            let raw = key.rawValue.lowercased()
            if raw == "title" || raw.contains("title") {
                if let v = item.stringValue, !v.isEmpty { title = v }
            } else if raw == "artist" || raw.contains("artist"), !raw.contains("album") {
                if let v = item.stringValue, !v.isEmpty { artist = v }
            } else if raw.contains("albumname") || raw == "album" {
                album = item.stringValue ?? album
            } else if raw.contains("lyrics") || raw == "lyr" {
                lyrics = item.stringValue ?? lyrics
            } else if raw.contains("description") || raw.contains("comment") {
                songDescription = item.stringValue ?? songDescription
            } else if raw == "type" || raw.contains("genre") {
                genre = item.stringValue ?? genre
            } else if raw.contains("creator") || raw.contains("composer") {
                composer = item.stringValue ?? composer
            } else if raw.contains("artwork") || raw.contains("art") {
                if let data = item.dataValue { artwork = data }
            } else if raw.contains("albumartist") || raw.contains("album artist") {
                albumArtist = item.stringValue ?? albumArtist
            }
        }

        // Format-specific fallbacks: ID3/iTunes use different key spaces; try to get track/disc/year from commonMetadata or by iterating again
        if trackNumber == nil || discNumber == nil || year == nil {
            for item in allMetadata {
                guard item.commonKey == nil else { continue }
                if let id = item.identifier?.rawValue {
                    if trackNumber == nil && (id.contains("track") || id.contains("Track")) {
                        trackNumber = item.numberValue?.intValue ?? item.stringValue.flatMap(parseTrackNumber)
                    }
                    if discNumber == nil && (id.contains("disc") || id.contains("Disc")) {
                        discNumber = item.numberValue?.intValue
                    }
                    if year == nil && (id.contains("year") || id.contains("Year") || id.contains("date")) {
                        year = item.numberValue?.intValue ?? item.stringValue.flatMap(parseYear)
                    }
                }
            }
        }

        return ExtractedAudioMetadata(
            title: title,
            artist: artist,
            duration: duration,
            lyrics: lyrics,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            songDescription: songDescription,
            trackNumber: trackNumber,
            discNumber: discNumber,
            year: year,
            composer: composer,
            artwork: artwork
        )
    }

    /// Parses "5", "5/12" -> 5
    private static func parseTrackNumber(_ s: String) -> Int? {
        let part = s.split(separator: "/").first.flatMap(String.init) ?? s
        return Int(part.trimmingCharacters(in: .whitespaces))
    }

    /// Parses year from "2024" or "2024-01-01"
    private static func parseYear(_ s: String) -> Int? {
        let part = String(s.prefix(4))
        return Int(part)
    }

    private static func loadDuration(from asset: AVURLAsset) async -> TimeInterval {
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds.isFinite && seconds >= 0 ? seconds : 0
        } catch {
            return 0
        }
    }
}
