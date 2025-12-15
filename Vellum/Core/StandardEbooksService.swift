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
    
    private let atomFeedURL = "https://standardebooks.org/feeds/atom"
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
            // Use the public HTML search page
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let searchURL = "https://standardebooks.org/ebooks?query=\(encodedQuery)&per-page=24"
            
            guard let url = URL(string: searchURL) else {
                throw StandardEbooksError.invalidURL
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw StandardEbooksError.networkError
            }
            
            let books = parseHTMLSearchResults(data: data)
            
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
    
    // MARK: - HTML Search Results Parsing
    
    private func parseHTMLSearchResults(data: Data) -> [StandardEbook] {
        var books: [StandardEbook] = []
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            return books
        }
        
        // Find all book entries: <li typeof="schema:Book" about="/ebooks/...">
        let bookPattern = "<li typeof=\"schema:Book\" about=\"(/ebooks/[^\"]+)\">"
        guard let regex = try? NSRegularExpression(pattern: bookPattern, options: []) else {
            return books
        }
        
        let matches = regex.matches(in: htmlString, options: [], range: NSRange(htmlString.startIndex..., in: htmlString))
        
        for match in matches {
            guard let bookPathRange = Range(match.range(at: 1), in: htmlString) else { continue }
            let bookPath = String(htmlString[bookPathRange])
            
            // Find the end of this <li> element
            guard let liStart = htmlString.range(of: "<li typeof=\"schema:Book\" about=\"\(bookPath)\">") else { continue }
            let searchStart = liStart.upperBound
            let remaining = String(htmlString[searchStart...])
            guard let liEnd = remaining.range(of: "</li>") else { continue }
            let liContent = String(remaining[..<liEnd.lowerBound])
            
            // Extract title: <span property="schema:name">Title</span> (first one is the book title)
            var title = "Unknown Title"
            if let titleMatch = liContent.range(of: "<span property=\"schema:name\">([^<]+)</span>", options: .regularExpression) {
                let titleTag = String(liContent[titleMatch])
                if let start = titleTag.range(of: ">"), let end = titleTag.range(of: "</") {
                    title = String(titleTag[start.upperBound..<end.lowerBound])
                }
            }
            
            // Extract author: second schema:name within the author section
            var author = "Unknown Author"
            if let authorSection = liContent.range(of: "<p class=\"author\"[^>]*>.*?</p>", options: .regularExpression) {
                let authorContent = String(liContent[authorSection])
                if let nameMatch = authorContent.range(of: "<span property=\"schema:name\">([^<]+)</span>", options: .regularExpression) {
                    let nameTag = String(authorContent[nameMatch])
                    if let start = nameTag.range(of: ">"), let end = nameTag.range(of: "</") {
                        author = String(nameTag[start.upperBound..<end.lowerBound])
                    }
                }
            }
            
            // Build URLs from the book path
            // EPUB URL: https://standardebooks.org/ebooks/{path}/downloads/{filename}.epub
            let pathComponents = bookPath.replacingOccurrences(of: "/ebooks/", with: "").components(separatedBy: "/")
            let filename = pathComponents.joined(separator: "_")
            let epubURL = URL(string: "https://standardebooks.org\(bookPath)/downloads/\(filename).epub")
            
            // Cover URL from the image in the HTML
            var coverURL: URL?
            if let imgMatch = liContent.range(of: "src=\"(/images/covers/[^\"]+)\"", options: .regularExpression) {
                let imgTag = String(liContent[imgMatch])
                if let srcStart = imgTag.range(of: "src=\""), let srcEnd = imgTag.range(of: "\"", range: imgTag.index(after: srcStart.upperBound)..<imgTag.endIndex) {
                    let imgPath = String(imgTag[srcStart.upperBound..<srcEnd.lowerBound])
                    coverURL = URL(string: "https://standardebooks.org\(imgPath)")
                }
            }
            
            let book = StandardEbook(
                id: bookPath,
                title: decodeHTMLEntities(title),
                author: decodeHTMLEntities(author),
                summary: "",
                epubURL: epubURL,
                coverURL: coverURL,
                updated: nil
            )
            books.append(book)
        }
        
        return books
    }
    
    // MARK: - Featured Books
    
    func loadFeaturedBooks() async {
        await MainActor.run {
            self.isSearching = true
        }
        
        do {
            // Load the public new-releases Atom feed
            guard let url = URL(string: "\(atomFeedURL)/new-releases") else {
                throw StandardEbooksError.invalidURL
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw StandardEbooksError.networkError
            }
            
            let books = parseAtomFeed(data: data)
            
            await MainActor.run {
                self.featuredBooks = books
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
    
    // MARK: - Atom Feed Parsing
    
    private func parseAtomFeed(data: Data) -> [StandardEbook] {
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
            
            // Extract cover image link - Atom feed uses media:thumbnail
            var coverURL: URL?
            // Look for media:thumbnail url="..."
            if let match = entryContent.range(of: "<media:thumbnail[^>]*url=\"([^\"]+)\"", options: .regularExpression) {
                let tag = String(entryContent[match])
                if let urlMatch = tag.range(of: "url=\"[^\"]+\"", options: .regularExpression) {
                    let href = String(tag[urlMatch]).dropFirst(5).dropLast(1)
                    coverURL = URL(string: String(href))
                }
            }
            
            // Fallback: look for any cover image link
            if coverURL == nil {
                if let imgMatch = entryContent.range(of: "url=\"[^\"]*cover[^\"]*\\.(jpg|jpeg|png)[^\"]*\"", options: [.regularExpression, .caseInsensitive]) {
                    let href = String(entryContent[imgMatch]).dropFirst(5).dropLast(1)
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
