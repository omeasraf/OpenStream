//
//  SongLibraryService.swift
//  OpenStream
//

import Foundation
import SwiftData

#if os(macOS)
    @preconcurrency import VLCKit
#else
    import MobileVLCKit
#endif

// MARK: - SongLibrary

@Observable
@MainActor
final class SongLibrary {
    static let shared = SongLibrary()

    private let fileManager = FileManager.default
    private(set) var songs: [LibrarySong] = []
    let songsDirectory: URL

    var modelContext: ModelContext? {
        didSet {
            if modelContext != nil {
                Task { await loadSongs() }
            }
        }
    }

    private init() {
        let baseDir =
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        songsDirectory = baseDir.appendingPathComponent(
            "Songs",
            isDirectory: true
        )
        try? fileManager.createDirectory(
            at: songsDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public API

    /// Import audio files from the given URLs. On macOS, URLs from fileImporter
    /// must be security-scoped; access is handled inside this method.
    func importFiles(_ urls: [URL]) async {
        guard let modelContext = modelContext else {
            return
        }

        var imported: [LibrarySong] = []

        for url in urls {
            if let song = await importFile(
                from: url,
                modelContext: modelContext
            ) {
                imported.append(song)
            }
        }

        guard !imported.isEmpty else { return }

        for song in imported {
            modelContext.insert(song)
        }
        saveContext()
        await loadSongs()
    }

    func deleteSong(_ song: LibrarySong) async {
        guard let modelContext = modelContext else { return }

        let fileURL = songsDirectory.appendingPathComponent(song.fileName)
        try? fileManager.removeItem(at: fileURL)

        modelContext.delete(song)
        saveContext()
        await loadSongs()
    }

    func getFileURL(for song: LibrarySong) -> URL {
        songsDirectory.appendingPathComponent(song.fileName)
    }

    func getMediaForPlayback(for song: LibrarySong) -> VLCMedia {
        VLCMedia(url: getFileURL(for: song))
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Loading

    private func loadSongs() async {
        guard let modelContext = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<LibrarySong>(
                sortBy: [SortDescriptor(\.importedDate, order: .reverse)]
            )
            let fetched = try modelContext.fetch(descriptor)
            songs = fetched
        } catch {
            songs = []
        }
    }

    // MARK: - Import (single file)

    private func importFile(from url: URL, modelContext: ModelContext) async
        -> LibrarySong?
    {
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            return nil
        }

        let fileHash = fileData.sha256()
        let fileSize = fileData.count

        // Skip if already in library
        do {
            var descriptor = FetchDescriptor<LibrarySong>(
                predicate: #Predicate<LibrarySong> { $0.fileHash == fileHash }
            )
            descriptor.fetchLimit = 1
            let count = try modelContext.fetchCount(descriptor)
            if count > 0 { return nil }
        } catch {
            return nil
        }

        let fileName =
            "song_\(UUID().uuidString.prefix(8))_\(url.lastPathComponent)"
        let destinationURL = songsDirectory.appendingPathComponent(fileName)

        do {
            try fileData.write(to: destinationURL)
        } catch {
            return nil
        }

        let metadata = await AudioMetadataExtractor.extract(
            from: destinationURL
        )

        return LibrarySong(
            title: metadata.title,
            artist: metadata.artist,
            fileName: fileName,
            fileHash: fileHash,
            size: fileSize,
            duration: metadata.duration,
            lyrics: metadata.lyrics,
            album: metadata.album,
            albumArtist: metadata.albumArtist,
            genre: metadata.genre,
            songDescription: metadata.songDescription,
            trackNumber: metadata.trackNumber,
            discNumber: metadata.discNumber,
            year: metadata.year,
            composer: metadata.composer,
            artwork: metadata.artwork
        )
    }

    // MARK: - Persistence

    private func saveContext() {
        guard let modelContext = modelContext else { return }
        try? modelContext.save()
    }
}
