import Foundation

enum KifStore {
    private static let supportedEncodings: [String.Encoding] = [.utf8, .shiftJIS, .japaneseEUC, .iso2022JP]

    nonisolated static func recordsDirectoryURL(isRunningInPreviews: Bool) throws -> URL {
        let baseURL: URL
        if isRunningInPreviews {
            baseURL = FileManager.default.temporaryDirectory
        } else {
            baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        let directoryURL = baseURL.appendingPathComponent("KifRecords", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    nonisolated static func listKifURLs(in directoryURL: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey]
        let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        var urls: [URL] = []
        while let next = enumerator?.nextObject() as? URL {
            guard next.pathExtension.lowercased() == "kif" else { continue }
            let values = try? next.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                urls.append(next)
            }
        }
        return urls
    }

    nonisolated static func readText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let text = decodeText(from: data) else {
            throw CocoaError(.fileReadUnknownStringEncoding)
        }
        return text
    }

    nonisolated static func decodeText(from data: Data) -> String? {
        for encoding in supportedEncodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return nil
    }

    nonisolated static func writeText(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    nonisolated static func uniqueFileURL(for preferredFilename: String, in directoryURL: URL) -> URL {
        let preferredURL = directoryURL.appendingPathComponent(preferredFilename)
        guard FileManager.default.fileExists(atPath: preferredURL.path) else {
            return preferredURL
        }

        let baseName = preferredURL.deletingPathExtension().lastPathComponent
        let ext = preferredURL.pathExtension
        var suffix = 1
        var candidate = preferredURL
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directoryURL
                .appendingPathComponent("\(baseName)_\(suffix)")
                .appendingPathExtension(ext)
            suffix += 1
        }
        return candidate
    }

    nonisolated static func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    nonisolated static func renameItem(originalURL: URL, safeTitle: String) throws -> URL {
        let directoryURL = originalURL.deletingLastPathComponent()
        var destinationURL = directoryURL.appendingPathComponent(safeTitle).appendingPathExtension("kif")
        var suffix = 1
        while FileManager.default.fileExists(atPath: destinationURL.path), destinationURL != originalURL {
            destinationURL = directoryURL
                .appendingPathComponent("\(safeTitle)_\(suffix)")
                .appendingPathExtension("kif")
            suffix += 1
        }

        if destinationURL != originalURL {
            try FileManager.default.moveItem(at: originalURL, to: destinationURL)
        }
        return destinationURL
    }

    nonisolated static func moveItemToFolder(originalURL: URL, baseDirectoryURL: URL, folderName: String) throws -> URL {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationDirectory: URL

        if trimmed.isEmpty {
            destinationDirectory = baseDirectoryURL
        } else {
            destinationDirectory = baseDirectoryURL.appendingPathComponent(trimmed, isDirectory: true)
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        }

        var destinationURL = destinationDirectory.appendingPathComponent(originalURL.lastPathComponent)
        var suffix = 1
        while FileManager.default.fileExists(atPath: destinationURL.path), destinationURL != originalURL {
            let baseName = originalURL.deletingPathExtension().lastPathComponent
            destinationURL = destinationDirectory
                .appendingPathComponent("\(baseName)_\(suffix)")
                .appendingPathExtension("kif")
            suffix += 1
        }

        if destinationURL != originalURL {
            try FileManager.default.moveItem(at: originalURL, to: destinationURL)
        }
        return destinationURL
    }
}
