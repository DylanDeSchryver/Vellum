import Foundation
import NaturalLanguage

class BookRecommendationService: ObservableObject {
    static let shared = BookRecommendationService()
    
    @Published var isProcessing = false
    @Published var recommendations: [BookRecommendation] = []
    @Published var error: String?
    
    private let embeddingModel: NLEmbedding?
    private var cachedEmbeddings: [UUID: [Double]] = [:]
    
    private init() {
        self.embeddingModel = NLEmbedding.sentenceEmbedding(for: .english)
    }
    
    struct BookRecommendation: Identifiable {
        let id = UUID()
        let title: String
        let author: String?
        let reason: String
        let similarityScore: Double
        let searchQuery: String
    }
    
    func generateRecommendations(from selectedDocuments: [Document], allDocuments: [Document]) async -> [BookRecommendation] {
        guard !selectedDocuments.isEmpty else {
            return []
        }
        
        await MainActor.run {
            isProcessing = true
            error = nil
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        let selectedEmbeddings = selectedDocuments.compactMap { document -> [Double]? in
            return generateEmbedding(for: document)
        }
        
        guard !selectedEmbeddings.isEmpty else {
            await MainActor.run {
                error = "Could not generate embeddings for selected books"
            }
            return []
        }
        
        let averageEmbedding = averageVectors(selectedEmbeddings)
        
        let unreadDocuments = allDocuments.filter { doc in
            !selectedDocuments.contains(where: { $0.id == doc.id })
        }
        
        var scoredBooks: [(document: Document, score: Double)] = []
        
        for document in unreadDocuments {
            if let embedding = generateEmbedding(for: document) {
                let similarity = cosineSimilarity(averageEmbedding, embedding)
                scoredBooks.append((document, similarity))
            }
        }
        
        scoredBooks.sort { $0.score > $1.score }
        
        let topBooks = Array(scoredBooks.prefix(3))
        
        let themes = extractThemes(from: selectedDocuments)
        let recommendations = topBooks.map { item in
            BookRecommendation(
                title: item.document.title ?? "Unknown",
                author: item.document.author,
                reason: generateReason(for: item.document, themes: themes, score: item.score),
                similarityScore: item.score,
                searchQuery: generateSearchQuery(for: item.document)
            )
        }
        
        if recommendations.isEmpty {
            let suggestedRecommendations = await generateExternalSuggestions(from: selectedDocuments, themes: themes)
            
            await MainActor.run {
                self.recommendations = suggestedRecommendations
            }
            return suggestedRecommendations
        }
        
        await MainActor.run {
            self.recommendations = recommendations
        }
        
        return recommendations
    }
    
    private func generateEmbedding(for document: Document) -> [Double]? {
        if let id = document.id, let cached = cachedEmbeddings[id] {
            return cached
        }
        
        let text = createTextRepresentation(for: document)
        
        guard let embedding = embeddingModel?.vector(for: text) else {
            return nil
        }
        
        let doubleEmbedding = embedding.map { Double($0) }
        
        if let id = document.id {
            cachedEmbeddings[id] = doubleEmbedding
        }
        
        return doubleEmbedding
    }
    
    private func createTextRepresentation(for document: Document) -> String {
        var components: [String] = []
        
        if let title = document.title {
            components.append(title)
        }
        
        if let author = document.author {
            components.append("by \(author)")
        }
        
        if let description = document.bookDescription, !description.isEmpty {
            let truncatedDescription = String(description.prefix(500))
            components.append(truncatedDescription)
        }
        
        if let subjects = document.subjects, !subjects.isEmpty {
            components.append("Topics: \(subjects)")
        }
        
        return components.joined(separator: ". ")
    }
    
    private func averageVectors(_ vectors: [[Double]]) -> [Double] {
        guard !vectors.isEmpty, let firstVector = vectors.first else {
            return []
        }
        
        var result = [Double](repeating: 0.0, count: firstVector.count)
        
        for vector in vectors {
            for (index, value) in vector.enumerated() where index < result.count {
                result[index] += value
            }
        }
        
        let count = Double(vectors.count)
        return result.map { $0 / count }
    }
    
    private func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else {
            return 0.0
        }
        
        var dotProduct = 0.0
        var magnitudeA = 0.0
        var magnitudeB = 0.0
        
        for i in 0..<vectorA.count {
            dotProduct += vectorA[i] * vectorB[i]
            magnitudeA += vectorA[i] * vectorA[i]
            magnitudeB += vectorB[i] * vectorB[i]
        }
        
        let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)
        
        guard magnitude > 0 else {
            return 0.0
        }
        
        return dotProduct / magnitude
    }
    
    private func extractThemes(from documents: [Document]) -> [String] {
        var themes: [String] = []
        
        let authors = documents.compactMap { $0.author }.filter { !$0.isEmpty }
        if !authors.isEmpty {
            themes.append("authors like \(authors.prefix(2).joined(separator: " and "))")
        }
        
        let titles = documents.compactMap { $0.title }
        let commonWords = findCommonThematicWords(in: titles)
        themes.append(contentsOf: commonWords.prefix(2))
        
        return themes
    }
    
    private func findCommonThematicWords(in titles: [String]) -> [String] {
        let stopWords = Set(["the", "a", "an", "of", "and", "to", "in", "for", "on", "with", "at", "by", "from", "or", "as", "is", "was", "are", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "shall", "can", "need", "dare", "ought", "used", "that", "this", "these", "those", "i", "you", "he", "she", "it", "we", "they", "what", "which", "who", "whom", "whose", "where", "when", "why", "how"])
        
        var wordCounts: [String: Int] = [:]
        
        for title in titles {
            let words = title.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 && !stopWords.contains($0) }
            
            for word in words {
                wordCounts[word, default: 0] += 1
            }
        }
        
        return wordCounts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key.capitalized }
    }
    
    private func generateReason(for document: Document, themes: [String], score: Double) -> String {
        if score > 0.8 {
            return "Highly similar to your selected books"
        } else if score > 0.6 {
            return "Strong thematic match with your reading preferences"
        } else if score > 0.4 {
            return "Good match based on your library"
        } else {
            return "May interest you based on your selections"
        }
    }
    
    private func generateSearchQuery(for document: Document) -> String {
        var query = document.title ?? ""
        if let author = document.author {
            query += " \(author)"
        }
        return query
    }
    
    private func generateExternalSuggestions(from selectedDocuments: [Document], themes: [String]) async -> [BookRecommendation] {
        let database = CuratedBookDatabase.shared
        
        // First, try to find curated profiles for selected books
        var bookProfiles: [BookProfile] = []
        var unknownBooks: [Document] = []
        
        for doc in selectedDocuments {
            if let title = doc.title, let profile = database.getProfile(for: title) {
                bookProfiles.append(profile)
            } else {
                unknownBooks.append(doc)
            }
        }
        
        // For books not in our database, create profiles from their metadata
        for doc in unknownBooks {
            if let title = doc.title {
                let profile = database.createProfileFromDocument(
                    title: title,
                    author: doc.author,
                    subjects: doc.subjects
                )
                bookProfiles.append(profile)
            }
        }
        
        // If we have profiles, use the curated matching system
        if !bookProfiles.isEmpty {
            let excludeTitles = Set(selectedDocuments.compactMap { $0.title })
            let matches = database.findBestMatches(for: bookProfiles, excludeTitles: excludeTitles, limit: 3)
            
            if !matches.isEmpty {
                return matches.enumerated().map { index, match in
                    let score = max(0.5, 0.95 - Double(index) * 0.1)
                    return BookRecommendation(
                        title: match.book.title,
                        author: match.book.author,
                        reason: match.reason,
                        similarityScore: score,
                        searchQuery: "\(match.book.title) \(match.book.author)"
                    )
                }
            }
        }
        
        // Fallback to Open Library search if curated matching fails
        var allSubjects: [String] = []
        
        for doc in selectedDocuments {
            if let subjects = doc.subjects {
                allSubjects.append(contentsOf: subjects.components(separatedBy: ", "))
            }
        }
        
        if allSubjects.isEmpty {
            for doc in selectedDocuments {
                if let title = doc.title {
                    if let metadata = await OpenLibraryService.shared.fetchMetadata(title: title, author: doc.author) {
                        allSubjects.append(contentsOf: metadata.subjects)
                    }
                }
            }
        }
        
        if allSubjects.isEmpty {
            allSubjects = ["classic literature", "adventure", "fiction"]
        }
        
        let excludeTitles = selectedDocuments.compactMap { $0.title }
        
        let suggestions = await OpenLibraryService.shared.searchSimilarBooks(
            subjects: allSubjects,
            excludeTitles: excludeTitles,
            limit: 10
        )
        
        let recommendations = suggestions.prefix(3).enumerated().map { index, book in
            let reason: String
            if let year = book.firstPublishYear {
                reason = "Classic from \(year) matching your reading themes"
            } else if let author = book.author {
                reason = "By \(author) - similar themes to your selections"
            } else {
                reason = "Recommended based on your reading preferences"
            }
            
            let score = max(0.5, 0.95 - Double(index) * 0.15)
            
            return BookRecommendation(
                title: book.title,
                author: book.author,
                reason: reason,
                similarityScore: score,
                searchQuery: "\(book.title) \(book.author ?? "")"
            )
        }
        
        if recommendations.isEmpty {
            return generateFallbackSuggestions(from: selectedDocuments)
        }
        
        return Array(recommendations)
    }
    
    private func generateFallbackSuggestions(from selectedDocuments: [Document]) -> [BookRecommendation] {
        let classicSuggestions = [
            ("Moby-Dick", "Herman Melville", "Epic adventure on the high seas"),
            ("The Count of Monte Cristo", "Alexandre Dumas", "Classic tale of adventure and revenge"),
            ("Robinson Crusoe", "Daniel Defoe", "The original survival adventure story")
        ]
        
        return classicSuggestions.enumerated().map { index, book in
            BookRecommendation(
                title: book.0,
                author: book.1,
                reason: book.2,
                similarityScore: 0.7 - Double(index) * 0.1,
                searchQuery: "\(book.0) \(book.1)"
            )
        }
    }
    
    func clearCache() {
        cachedEmbeddings.removeAll()
    }
}
