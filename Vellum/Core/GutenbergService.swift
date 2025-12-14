import Foundation
import SwiftUI

// MARK: - Gutenberg API Models

struct GutenbergSearchResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [GutenbergBook]
}

struct GutenbergBook: Codable, Identifiable {
    let id: Int
    let title: String
    let authors: [GutenbergAuthor]
    let subjects: [String]
    let bookshelves: [String]
    let languages: [String]
    let copyright: Bool?
    let mediaType: String
    let formats: [String: String]
    let downloadCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, authors, subjects, bookshelves, languages, copyright, formats
        case mediaType = "media_type"
        case downloadCount = "download_count"
    }
    
    var authorName: String {
        authors.first?.name ?? "Unknown Author"
    }
    
    var epubURL: URL? {
        // Prefer epub with images, then regular epub
        if let urlString = formats["application/epub+zip"] {
            return URL(string: urlString)
        }
        return nil
    }
    
    var coverURL: URL? {
        if let urlString = formats["image/jpeg"] {
            return URL(string: urlString)
        }
        return nil
    }
    
    var isPublicDomain: Bool {
        copyright == false || copyright == nil
    }
}

struct GutenbergAuthor: Codable {
    let name: String
    let birthYear: Int?
    let deathYear: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case birthYear = "birth_year"
        case deathYear = "death_year"
    }
}

// MARK: - Gutenberg Service

class GutenbergService: ObservableObject {
    static let shared = GutenbergService()
    
    @Published var searchResults: [GutenbergBook] = []
    @Published var isSearching = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var currentDownloadTitle: String?
    @Published var error: String?
    @Published var popularBooks: [GutenbergBook] = []
    
    private let baseURL = "https://gutendex.com/books"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Search
    
    func search(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                self.searchResults = []
            }
            return
        }
        
        await MainActor.run {
            self.isSearching = true
            self.error = nil
        }
        
        do {
            var components = URLComponents(string: baseURL)!
            components.queryItems = [
                URLQueryItem(name: "search", value: query),
                URLQueryItem(name: "languages", value: "en"),
                URLQueryItem(name: "copyright", value: "false")
            ]
            
            guard let url = components.url else {
                throw GutenbergError.invalidURL
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw GutenbergError.networkError
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(GutenbergSearchResponse.self, from: data)
            
            // Filter to only books with EPUB available
            let booksWithEpub = searchResponse.results.filter { $0.epubURL != nil }
            
            await MainActor.run {
                self.searchResults = booksWithEpub
                self.isSearching = false
            }
            
        } catch {
            await MainActor.run {
                self.error = "Search failed: \(error.localizedDescription)"
                self.isSearching = false
            }
        }
    }
    
    // MARK: - Popular Books
    
    func loadPopularBooks() async {
        await MainActor.run {
            self.isSearching = true
        }
        
        do {
            var components = URLComponents(string: baseURL)!
            components.queryItems = [
                URLQueryItem(name: "languages", value: "en"),
                URLQueryItem(name: "copyright", value: "false"),
                URLQueryItem(name: "sort", value: "popular")
            ]
            
            guard let url = components.url else {
                throw GutenbergError.invalidURL
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw GutenbergError.networkError
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(GutenbergSearchResponse.self, from: data)
            
            let booksWithEpub = searchResponse.results.filter { $0.epubURL != nil }
            
            await MainActor.run {
                self.popularBooks = booksWithEpub
                self.isSearching = false
            }
            
        } catch {
            await MainActor.run {
                self.error = "Failed to load popular books: \(error.localizedDescription)"
                self.isSearching = false
            }
        }
    }
    
    // MARK: - Download
    
    func downloadBook(_ book: GutenbergBook) async -> URL? {
        guard let epubURL = book.epubURL else {
            await MainActor.run {
                self.error = "No EPUB available for this book"
            }
            return nil
        }
        
        await MainActor.run {
            self.isDownloading = true
            self.downloadProgress = 0
            self.currentDownloadTitle = book.title
            self.error = nil
        }
        
        do {
            // Create download task with progress
            let (tempURL, response) = try await session.download(from: epubURL)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw GutenbergError.downloadFailed
            }
            
            // Move to documents directory
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let libraryPath = documentsPath.appendingPathComponent("VellumLibrary", isDirectory: true)
            
            // Create library directory if needed
            if !fileManager.fileExists(atPath: libraryPath.path) {
                try fileManager.createDirectory(at: libraryPath, withIntermediateDirectories: true)
            }
            
            // Create unique filename
            let safeTitle = book.title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .prefix(50)
            let fileName = "\(UUID().uuidString)_\(safeTitle).epub"
            let destinationURL = libraryPath.appendingPathComponent(fileName)
            
            // Remove if exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            
            await MainActor.run {
                self.isDownloading = false
                self.downloadProgress = 1.0
                self.currentDownloadTitle = nil
            }
            
            return destinationURL
            
        } catch {
            await MainActor.run {
                self.error = "Download failed: \(error.localizedDescription)"
                self.isDownloading = false
                self.currentDownloadTitle = nil
            }
            return nil
        }
    }
    
    // MARK: - Download Cover Image
    
    func downloadCoverImage(_ book: GutenbergBook) async -> Data? {
        guard let coverURL = book.coverURL else { return nil }
        
        do {
            let (data, response) = try await session.data(from: coverURL)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            return data
        } catch {
            return nil
        }
    }
}

// MARK: - Errors

enum GutenbergError: LocalizedError {
    case invalidURL
    case networkError
    case downloadFailed
    case noEpubAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .downloadFailed:
            return "Download failed"
        case .noEpubAvailable:
            return "No EPUB format available for this book"
        }
    }
}
