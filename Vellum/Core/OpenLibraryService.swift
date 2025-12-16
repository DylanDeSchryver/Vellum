import Foundation

class OpenLibraryService {
    static let shared = OpenLibraryService()
    
    private let baseURL = "https://openlibrary.org"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        self.session = URLSession(configuration: config)
    }
    
    struct BookMetadata {
        let description: String?
        let subjects: [String]
        let coverURL: String?
    }
    
    struct BookSuggestion {
        let title: String
        let author: String?
        let firstPublishYear: Int?
        let subjects: [String]
        let coverURL: String?
        let workKey: String?
    }
    
    func searchSimilarBooks(subjects: [String], excludeTitles: [String], limit: Int = 10) async -> [BookSuggestion] {
        let prioritySubjects = ["adventure", "classic", "fiction", "literature", "coming of age", "american literature", "19th century", "20th century"]
        
        let filteredSubjects = subjects
            .map { $0.lowercased() }
            .filter { subject in
                prioritySubjects.contains(where: { subject.contains($0) }) ||
                subject.count > 4
            }
            .prefix(3)
        
        var allResults: [BookSuggestion] = []
        let excludeTitlesLower = Set(excludeTitles.map { $0.lowercased() })
        
        for subject in filteredSubjects {
            let results = await searchBySubject(subject: String(subject), limit: 15)
            let filtered = results.filter { book in
                guard let title = book.title?.lowercased() else { return false }
                return !excludeTitlesLower.contains(where: { title.contains($0) || $0.contains(title) })
            }
            allResults.append(contentsOf: filtered.map { result in
                BookSuggestion(
                    title: result.title ?? "Unknown",
                    author: result.authorName?.first,
                    firstPublishYear: result.firstPublishYear,
                    subjects: result.subjects ?? [],
                    coverURL: result.coverID.map { "https://covers.openlibrary.org/b/id/\($0)-M.jpg" },
                    workKey: result.key
                )
            })
        }
        
        var seen = Set<String>()
        let unique = allResults.filter { book in
            let key = book.title.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        
        return Array(unique.prefix(limit))
    }
    
    private func searchBySubject(subject: String, limit: Int) async -> [SearchResult] {
        var components = URLComponents(string: "\(baseURL)/search.json")!
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "fields", value: "key,title,author_name,first_publish_year,cover_i,subject"),
            URLQueryItem(name: "sort", value: "rating")
        ]
        
        guard let url = components.url else { return [] }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            return searchResponse.docs
        } catch {
            print("OpenLibrary subject search error: \(error)")
            return []
        }
    }
    
    func fetchMetadata(title: String, author: String?) async -> BookMetadata? {
        let searchResults = await searchBooks(title: title, author: author)
        
        guard let firstResult = searchResults.first else {
            return nil
        }
        
        var description: String? = nil
        var subjects = firstResult.subjects ?? []
        let coverURL = firstResult.coverID.map { "https://covers.openlibrary.org/b/id/\($0)-M.jpg" }
        
        if let workKey = firstResult.workKey {
            if let workDetails = await fetchWorkDetails(workKey: workKey) {
                description = workDetails.description
                if subjects.isEmpty {
                    subjects = workDetails.subjects
                }
            }
        }
        
        return BookMetadata(
            description: description,
            subjects: subjects,
            coverURL: coverURL
        )
    }
    
    private func searchBooks(title: String, author: String?) async -> [SearchResult] {
        var queryItems = [URLQueryItem(name: "title", value: title)]
        if let author = author, !author.isEmpty {
            queryItems.append(URLQueryItem(name: "author", value: author))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "3"))
        queryItems.append(URLQueryItem(name: "fields", value: "key,title,author_name,first_publish_year,cover_i,subject,edition_key"))
        
        var components = URLComponents(string: "\(baseURL)/search.json")!
        components.queryItems = queryItems
        
        guard let url = components.url else { return [] }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            return searchResponse.docs
        } catch {
            print("OpenLibrary search error: \(error)")
            return []
        }
    }
    
    private func fetchWorkDetails(workKey: String) async -> WorkDetails? {
        let urlString = "\(baseURL)\(workKey).json"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let work = try JSONDecoder().decode(WorkResponse.self, from: data)
            
            var descriptionText: String? = nil
            if let desc = work.description {
                switch desc {
                case .string(let text):
                    descriptionText = text
                case .object(let obj):
                    descriptionText = obj.value
                }
            }
            
            return WorkDetails(
                description: descriptionText,
                subjects: work.subjects ?? []
            )
        } catch {
            print("OpenLibrary work details error: \(error)")
            return nil
        }
    }
}

// MARK: - Response Models

private struct SearchResponse: Decodable {
    let docs: [SearchResult]
}

private struct SearchResult: Decodable {
    let key: String?
    let title: String?
    let authorName: [String]?
    let firstPublishYear: Int?
    let coverID: Int?
    let subjects: [String]?
    let editionKeys: [String]?
    
    var workKey: String? {
        key
    }
    
    enum CodingKeys: String, CodingKey {
        case key
        case title
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case coverID = "cover_i"
        case subjects = "subject"
        case editionKeys = "edition_key"
    }
}

private struct WorkResponse: Decodable {
    let description: DescriptionValue?
    let subjects: [String]?
}

private enum DescriptionValue: Decodable {
    case string(String)
    case object(DescriptionObject)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let objectValue = try? container.decode(DescriptionObject.self) {
            self = .object(objectValue)
        } else {
            throw DecodingError.typeMismatch(
                DescriptionValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Object")
            )
        }
    }
}

private struct DescriptionObject: Decodable {
    let type: String?
    let value: String
}

private struct WorkDetails {
    let description: String?
    let subjects: [String]
}
