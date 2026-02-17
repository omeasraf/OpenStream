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
    let artworkCacheDirectory: URL

    /// Indexing status for startup and Files app sync. Visible on all pages except OpenPlayerView.
    private(set) var indexingStatus: IndexingStatus = .idle

    var modelContext: ModelContext? {
        didSet {
            if modelContext != nil {
                Task { await indexOnStartup() }
            }
        }
    }

    private static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "wav", "ogg", "opus", "aiff", "wma", "alac", "m4b"
    ]

    private init() {
        let baseDir =
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        songsDirectory = baseDir.appendingPathComponent(
            "Songs",
            isDirectory: true
        )
        artworkCacheDirectory = baseDir.appendingPathComponent(
            ".artwork-cache",
            isDirectory: true
        )
        try? fileManager.createDirectory(
            at: songsDirectory,
            withIntermediateDirectories: true
        )
        try? fileManager.createDirectory(
            at: artworkCacheDirectory,
            withIntermediateDirectories: true
        )
        // Ensure Documents has content so the app folder appears in Files app
        ensureDocumentsPlaceholder(in: baseDir)
    }

    /// Creates a placeholder file in Documents so the OpenStream folder appears in Files app.
    private func ensureDocumentsPlaceholder(in documentsURL: URL) {
        let placeholder = documentsURL.appendingPathComponent("OpenStream.txt", isDirectory: false)
        guard !fileManager.fileExists(atPath: placeholder.path) else { return }
        let text = "OpenStream music library.\nAdd audio files to the Songs folder to import them."
        try? text.write(to: placeholder, atomically: true, encoding: .utf8)
    }

    // MARK: - Artwork Caching

    /// Saves artwork data to the cache and returns the file path.
    /// Uses hash of artwork data as the filename to avoid duplicates (Spotify-like approach).
    private func cacheArtwork(_ artworkData: Data) -> String? {
        guard !artworkData.isEmpty else { return nil }

        let hash = artworkData.sha256()
        let fileName = "\(hash).jpg"
        let artworkPath = artworkCacheDirectory.appendingPathComponent(fileName)

        // If artwork already cached, return the path
        if fileManager.fileExists(atPath: artworkPath.path) {
            return artworkPath.path
        }

        // Write artwork to cache
        do {
            try artworkData.write(to: artworkPath)
            return artworkPath.path
        } catch {
            return nil
        }
    }

    // MARK: - Metadata Sidecar Management

    /// Generates a conventional filename from song metadata.
    /// Format: "Artist - Title.ext" or "Track# - Artist - Title.ext" if track number exists
    /// Handles special characters and duplicate filenames.
    private func generateFileName(
        artist: String,
        title: String,
        trackNumber: Int?,
        originalExtension: String
    ) -> String {
        let sanitized = { (str: String) -> String in
            str.replacingOccurrences(of: "[/\\:*?\"<>|]", with: "_", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }

        let artistSanitized = sanitized(artist.isEmpty ? "Unknown" : artist)
        let titleSanitized = sanitized(title.isEmpty ? "Untitled" : title)

        let baseName: String
        if let trackNum = trackNumber, trackNum > 0 {
            let paddedTrack = String(format: "%02d", trackNum)
            baseName = "\(paddedTrack) - \(artistSanitized) - \(titleSanitized)"
        } else {
            baseName = "\(artistSanitized) - \(titleSanitized)"
        }

        let ext = originalExtension.isEmpty ? "mp3" : originalExtension.lowercased()
        return "\(baseName).\(ext)"
    }

    /// Saves metadata to JSON sidecar file next to the song.
    /// Returns true if successful.
    private func saveMetadataSidecar(for song: LibrarySong, at fileURL: URL) -> Bool {
        let metadata = SongMetadata(from: song)
        let sidecarURL = fileURL.appendingPathExtension("metadata.json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(metadata)
            try jsonData.write(to: sidecarURL)
            return true
        } catch {
            return false
        }
    }

    /// Loads metadata from JSON sidecar if it exists, otherwise returns nil.
    private func loadMetadataSidecar(for fileName: String, in directory: URL) -> SongMetadata? {
        let fileURL = directory.appendingPathComponent(fileName)
        let sidecarURL = fileURL.appendingPathExtension("metadata.json")

        guard fileManager.fileExists(atPath: sidecarURL.path) else { return nil }

        do {
            let jsonData = try Data(contentsOf: sidecarURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SongMetadata.self, from: jsonData)
        } catch {
            return nil
        }
    }

    /// Gets or creates a unique filename if duplicates exist.
    private func getUniqueFileName(
        baseName: String,
        in directory: URL
    ) -> String {
        let url = directory.appendingPathComponent(baseName)
        
        // If file doesn't exist, use as-is
        guard fileManager.fileExists(atPath: url.path) else {
            return baseName
        }

        // File exists, add counter
        let parts = baseName.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let nameWithoutExt = String(parts[0])
        let ext = parts.count > 1 ? "." + String(parts[1]) : ""

        var counter = 1
        while counter < 1000 {
            let newName = "\(nameWithoutExt) (\(counter))\(ext)"
            let newURL = directory.appendingPathComponent(newName)
            if !fileManager.fileExists(atPath: newURL.path) {
                return newName
            }
            counter += 1
        }

        // Fallback: use UUID if somehow we still have conflicts
        return "\(nameWithoutExt) (\(UUID().uuidString.prefix(8)))\(ext)"
    }

    /// Validates and repairs artwork paths. If a path is invalid, re-extracts and caches artwork.
    /// Returns the valid path or nil if artwork cannot be obtained.
    private func validateOrRepairArtworkPath(for song: LibrarySong, fileURL: URL) async -> String? {
        // If path exists and file is accessible, return it
        if let path = song.artworkPath, fileManager.fileExists(atPath: path) {
            return path
        }

        // Path is missing or invalid, re-extract artwork from the audio file
        let metadata = await AudioMetadataExtractor.extract(from: fileURL)
        if let artworkData = metadata.artwork {
            return cacheArtwork(artworkData)
        }

        return nil
    }

    /// Gets the directory for an album (organized by artist/album or flat by album).
    private func getAlbumDirectory(
        album: String?,
        artist: String?,
        groupByAlbum: Bool
    ) -> URL {
        guard groupByAlbum, let albumName = album, !albumName.isEmpty else {
            return songsDirectory
        }

        // Organize as: Songs/Artist Name/Album Name/ or Songs/Album Name/
        let albumDirName = "\(albumName)"
        return songsDirectory.appendingPathComponent(albumDirName, isDirectory: true)
    }

    // MARK: - Indexing

    /// Scans the Songs directory on startup and syncs with the database.
    /// Imports new files (e.g. added via Files app) and removes entries for deleted files.
    func indexOnStartup() async {
        guard let modelContext = modelContext else { return }

        indexingStatus = .indexing("Scanning…")
        defer { indexingStatus = .complete }

        let settings = AppSettings.getOrCreate(in: modelContext)

        try? fileManager.createDirectory(
            at: songsDirectory,
            withIntermediateDirectories: true
        )

        let descriptor = FetchDescriptor<LibrarySong>()
        let existingSongs: [LibrarySong]
        do {
            existingSongs = try modelContext.fetch(descriptor)
        } catch {
            await loadSongs()
            return
        }

        // 1. Remove DB entries for files that no longer exist
        let existingFileNames = Set(existingSongs.map(\.fileName))
        for song in existingSongs {
            let url = getAlbumDirectory(
                album: song.album,
                artist: song.artist,
                groupByAlbum: settings.groupSongsByAlbum
            ).appendingPathComponent(song.fileName)
            if !fileManager.fileExists(atPath: url.path) {
                modelContext.delete(song)
            }
        }

        // 2. Find audio files on disk (including in album subdirectories)
        let audioURLs = findAudioFiles(in: songsDirectory)

        // 3. Import new files not in DB (files added via Files app or already in place)
        for url in audioURLs {
            let fileName = url.lastPathComponent
            if existingFileNames.contains(fileName) { continue }

            if let song = await importFileInPlace(at: url, modelContext: modelContext) {
                modelContext.insert(song)
            }
        }

        saveContext()
        await loadSongs()
    }

    /// Recursively finds all audio files in the directory structure.
    private func findAudioFiles(in directory: URL) -> [URL] {
        var audioFiles: [URL] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            return audioFiles
        }

        for url in contents {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDir {
                // Recursively search subdirectories (for album folders)
                audioFiles.append(contentsOf: findAudioFiles(in: url))
            } else {
                let ext = url.pathExtension.lowercased()
                if Self.audioExtensions.contains(ext) {
                    audioFiles.append(url)
                }
            }
        }

        return audioFiles
    }

    // MARK: - Public API

    /// Import audio files from the given URLs. On macOS, URLs from fileImporter
    /// must be security-scoped; access is handled inside this method.
    func importFiles(_ urls: [URL]) async {
        guard let modelContext = modelContext else {
            return
        }

        let settings = AppSettings.getOrCreate(in: modelContext)

        var imported: [LibrarySong] = []

        for url in urls {
            if let song = await importFile(
                from: url,
                modelContext: modelContext,
                groupByAlbum: settings.groupSongsByAlbum
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

        let settings = AppSettings.getOrCreate(in: modelContext)
        let fileURL = getAlbumDirectory(
            album: song.album,
            artist: song.artist,
            groupByAlbum: settings.groupSongsByAlbum
        ).appendingPathComponent(song.fileName)
        try? fileManager.removeItem(at: fileURL)

        modelContext.delete(song)
        saveContext()
        await loadSongs()
    }

    func getFileURL(for song: LibrarySong) -> URL {
        guard let modelContext = modelContext else {
            return songsDirectory.appendingPathComponent(song.fileName)
        }

        // Fetch current settings
        let settings = AppSettings.getOrCreate(in: modelContext)
        return getAlbumDirectory(
            album: song.album,
            artist: song.artist,
            groupByAlbum: settings.groupSongsByAlbum
        ).appendingPathComponent(song.fileName)
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
            
            // Validate and repair artwork paths for all loaded songs
            var songsToUpdate: [LibrarySong] = []
            for song in fetched {
                let fileURL = getFileURL(for: song)
                if let validPath = await validateOrRepairArtworkPath(for: song, fileURL: fileURL) {
                    if validPath != song.artworkPath {
                        song.artworkPath = validPath
                        songsToUpdate.append(song)
                    }
                } else if song.artworkPath != nil {
                    song.artworkPath = nil
                    songsToUpdate.append(song)
                }
            }
            
            // Save any updates
            if !songsToUpdate.isEmpty {
                saveContext()
            }
            
            songs = fetched
        } catch {
            songs = []
        }
    }

    // MARK: - Import (single file)

    /// Imports a file already located in songsDirectory (e.g. added via Files app).
    /// Uses the existing filename; does not copy the file.
    private func importFileInPlace(at url: URL, modelContext: ModelContext) async -> LibrarySong? {
        let fileName = url.lastPathComponent
        guard url.deletingLastPathComponent().path == songsDirectory.path
            || findAudioFiles(in: songsDirectory).contains(url)
        else { return nil }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            return nil
        }

        let fileHash = fileData.sha256()
        let fileSize = fileData.count

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

        let metadata = await AudioMetadataExtractor.extract(from: url)
        let artworkPath = metadata.artwork.flatMap { cacheArtwork($0) }

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
            artworkPath: artworkPath
        )
    }

    /// Imports from an external URL (file importer), copies into songsDirectory.
    private func importFile(
        from url: URL,
        modelContext: ModelContext,
        groupByAlbum: Bool
    ) async -> LibrarySong? {
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

        // Extract metadata first to determine album organization
        let metadata = await AudioMetadataExtractor.extract(from: url)
        
        // Generate conventional filename
        let fileName = generateFileName(
            artist: metadata.artist,
            title: metadata.title,
            trackNumber: metadata.trackNumber,
            originalExtension: url.pathExtension
        )
        
        let albumDir = getAlbumDirectory(
            album: metadata.album,
            artist: metadata.artist,
            groupByAlbum: groupByAlbum
        )
        
        // Create album directory if needed
        try? fileManager.createDirectory(
            at: albumDir,
            withIntermediateDirectories: true
        )
        
        // Get unique filename if one already exists
        let uniqueFileName = getUniqueFileName(baseName: fileName, in: albumDir)
        let destinationURL = albumDir.appendingPathComponent(uniqueFileName)

        do {
            try fileData.write(to: destinationURL)
        } catch {
            return nil
        }

        // Cache artwork and get path
        let artworkPath = metadata.artwork.flatMap { cacheArtwork($0) }

        let song = LibrarySong(
            title: metadata.title,
            artist: metadata.artist,
            fileName: uniqueFileName,
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
            artworkPath: artworkPath
        )
        
        // Save metadata sidecar
        _ = saveMetadataSidecar(for: song, at: destinationURL)
        
        return song
    }

    // MARK: - Persistence

    private func saveContext() {
        guard let modelContext = modelContext else { return }
        try? modelContext.save()
    }
}
