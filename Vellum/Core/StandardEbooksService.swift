import Foundation
import SwiftUI

// MARK: - Standard Ebooks Models

struct StandardEbook: Identifiable {
    let id: String
    let title: String
    let author: String
    let summary: String
    let epubURL: URL?
    let coverURL: URL?
    let updated: Date?
    
    var authorName: String {
        author
    }
}

// MARK: - Standard Ebooks Service

class StandardEbooksService: ObservableObject {
    static let shared = StandardEbooksService()
    
    @Published var searchResults: [StandardEbook] = []
    @Published var isSearching = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var currentDownloadTitle: String?
    @Published var error: String?
    @Published var featuredBooks: [StandardEbook] = []
    
    private let opdsBaseURL = "https://standardebooks.org/feeds/opds"
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
            // Standard Ebooks OPDS search endpoint
            let searchURL = "\(opdsBaseURL)/all?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
            
            guard let url = URL(string: searchURL) else {
                throw StandardEbooksError.invalidURL
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw StandardEbooksError.networkError
            }
            
            let books = parseOPDSFeed(data: data)
            
            await MainActor.run {
                self.searchResults = books
                self.isSearching = false
            }
            
        } catch {
            await MainActor.run {
                self.error = "Search failed: \(error.localizedDescription)"
                self.isSearching = false
            }
        }
    }
    
    // MARK: - Featured Books
    
    func loadFeaturedBooks() async {
        await MainActor.run {
            self.isSearching = true
        }
        
        do {
            // Load the all books feed (new-releases may not exist)
            guard let url = URL(string: "\(opdsBaseURL)/all") else {
                throw StandardEbooksError.invalidURL
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw StandardEbooksError.networkError
            }
            
            let books = parseOPDSFeed(data: data)
            
            await MainActor.run {
                // Take first 20 as "featured"
                self.featuredBooks = Array(books.prefix(20))
                self.isSearching = false
            }
            
        } catch {
            // Silently fail - user can still search
            await MainActor.run {
                self.featuredBooks = []
                self.isSearching = false
            }
        }
    }
    
    // MARK: - OPDS Feed Parsing
    
    private func parseOPDSFeed(data: Data) -> [StandardEbook] {
        var books: [StandardEbook] = []
        
        guard let xmlString = String(data: data, encoding: .utf8) else {
            return books
        }
        
        // Split by entry tags
        let entries = xmlString.components(separatedBy: "<entry>")
        
        for entry in entries.dropFirst() {
            guard let entryEnd = entry.range(of: "</entry>") else { continue }
            let entryContent = String(entry[..<entryEnd.lowerBound])
            
            // Extract ID
            let id = extractTag(from: entryContent, tag: "id") ?? UUID().uuidString
            
            // Extract title
            let title = extractTag(from: entryContent, tag: "title") ?? "Unknown Title"
            
            // Extract author
            var author = "Unknown Author"
            if let authorStart = entryContent.range(of: "<author>"),
               let authorEnd = entryContent.range(of: "</author>") {
                let authorContent = String(entryContent[authorStart.upperBound..<authorEnd.lowerBound])
                author = extractTag(from: authorContent, tag: "name") ?? "Unknown Author"
            }
            
            // Extract summary/description
            let summary = extractTag(from: entryContent, tag: "summary") ?? 
                          extractTag(from: entryContent, tag: "content") ?? ""
            
            // Extract EPUB link
            var epubURL: URL?
            // Look for application/epub+zip link
            let linkPattern = "<link[^>]*href=\"([^\"]+)\"[^>]*type=\"application/epub\\+zip\"[^>]*/>"
            let linkPatternAlt = "<link[^>]*type=\"application/epub\\+zip\"[^>]*href=\"([^\"]+)\"[^>]*/>"
            
            if let match = entryContent.range(of: linkPattern, options: .regularExpression) {
                let linkTag = String(entryContent[match])
                if let hrefMatch = linkTag.range(of: "href=\"[^\"]+\"", options: .regularExpression) {
                    let href = String(linkTag[hrefMatch]).dropFirst(6).dropLast(1)
                    epubURL = URL(string: String(href))
                }
            } else if let match = entryContent.range(of: linkPatternAlt, options: .regularExpression) {
                let linkTag = String(entryContent[match])
                if let hrefMatch = linkTag.range(of: "href=\"[^\"]+\"", options: .regularExpression) {
                    let href = String(linkTag[hrefMatch]).dropFirst(6).dropLast(1)
                    epubURL = URL(string: String(href))
                }
            }
            
            // Fallback: find any link with .epub
            if epubURL == nil {
                if let epubMatch = entryContent.range(of: "href=\"[^\"]*\\.epub[^\"]*\"", options: .regularExpression) {
                    let href = String(entryContent[epubMatch]).dropFirst(6).dropLast(1)
                    epubURL = URL(string: String(href))
                }
            }
            
            // Extract cover image link
            var coverURL: URL?
            let coverPattern = "<link[^>]*rel=\"http://opds-spec.org/image\"[^>]*href=\"([^\"]+)\"[^>]*/>"
            let coverPatternAlt = "<link[^>]*href=\"([^\"]+)\"[^>]*rel=\"http://opds-spec.org/image\"[^>]*/>"
            
            if let match = entryContent.range(of: coverPattern, options: .regularExpression) {
                let linkTag = String(entryContent[match])
                if let hrefMatch = linkTag.range(of: "href=\"[^\"]+\"", options: .regularExpression) {
                    let href = String(linkTag[hrefMatch]).dropFirst(6).dropLast(1)
                    coverURL = URL(string: String(href))
                }
            } else if let match = entryContent.range(of: coverPatternAlt, options: .regularExpression) {
                let linkTag = String(entryContent[match])
                if let hrefMatch = linkTag.range(of: "href=\"[^\"]+\"", options: .regularExpression) {
                    let href = String(linkTag[hrefMatch]).dropFirst(6).dropLast(1)
                    coverURL = URL(string: String(href))
                }
            }
            
            // Fallback: look for any image link
            if coverURL == nil {
                if let imgMatch = entryContent.range(of: "href=\"[^\"]*cover[^\"]*\\.(jpg|jpeg|png)[^\"]*\"", options: [.regularExpression, .caseInsensitive]) {
                    let href = String(entryContent[imgMatch]).dropFirst(6).dropLast(1)
                    coverURL = URL(string: String(href))
                }
            }
            
            // Only add if we have an EPUB URL
            if epubURL != nil {
                let book = StandardEbook(
                    id: id,
                    title: decodeHTMLEntities(title),
                    author: decodeHTMLEntities(author),
                    summary: decodeHTMLEntities(summary),
                    epubURL: epubURL,
                    coverURL: coverURL,
                    updated: nil
                )
                books.append(book)
            }
        }
        
        return books
    }
    
    private func extractTag(from content: String, tag: String) -> String? {
        // Handle both simple tags and tags with attributes
        let patterns = [
            "<\(tag)>([^<]*)</\(tag)>",
            "<\(tag)[^>]*>([^<]*)</\(tag)>"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                return String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&mdash;", with: "\u{2014}")
        result = result.replacingOccurrences(of: "&ndash;", with: "\u{2013}")
        result = result.replacingOccurrences(of: "&hellip;", with: "\u{2026}")
        result = result.replacingOccurrences(of: "&ldquo;", with: "\u{201C}")
        result = result.replacingOccurrences(of: "&rdquo;", with: "\u{201D}")
        result = result.replacingOccurrences(of: "&lsquo;", with: "\u{2018}")
        result = result.replacingOccurrences(of: "&rsquo;", with: "\u{2019}")
        return result
    }
    
    // MARK: - Download
    
    func downloadBook(_ book: StandardEbook) async -> URL? {
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
            let (tempURL, response) = try await session.download(from: epubURL)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw StandardEbooksError.downloadFailed
            }
            
            // Move to documents directory
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let libraryPath = documentsPath.appendingPathComponent("VellumLibrary", isDirectory: true)
            
            if !fileManager.fileExists(atPath: libraryPath.path) {
                try fileManager.createDirectory(at: libraryPath, withIntermediateDirectories: true)
            }
            
            let safeTitle = book.title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .prefix(50)
            let fileName = "\(UUID().uuidString)_\(safeTitle).epub"
            let destinationURL = libraryPath.appendingPathComponent(fileName)
            
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
    
    func downloadCoverImage(_ book: StandardEbook) async -> Data? {
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

enum StandardEbooksError: LocalizedError {
    case invalidURL
    case networkError
    case downloadFailed
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .downloadFailed:
            return "Download failed"
        case .parseError:
            return "Failed to parse feed"
        }
    }
}
