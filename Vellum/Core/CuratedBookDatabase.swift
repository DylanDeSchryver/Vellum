import Foundation

struct BookProfile {
    let title: String
    let author: String
    let era: BookEra
    let style: Set<LiteraryStyle>
    let themes: Set<Theme>
    let recommendations: [String]  // Titles of recommended books
    
    enum BookEra: String, CaseIterable {
        case classical       // Pre-1800
        case nineteenth      // 1800-1899
        case earlyModern     // 1900-1945
        case midCentury      // 1945-1980
        case contemporary    // 1980-present
    }
    
    enum LiteraryStyle: String, CaseIterable {
        case literary
        case adventure
        case comingOfAge
        case socialCommentary
        case symbolism
        case conciseProse
        case ornateStyle
        case strongVoice
        case philosophical
        case satirical
        case gothic
        case romantic
        case realist
        case naturalist
        case modernist
        case humorous
    }
    
    enum Theme: String, CaseIterable {
        case americanDream
        case moralGrowth
        case friendship
        case survival
        case identity
        case classStruggle
        case innocenceLost
        case nature
        case freedom
        case justice
        case adventure
        case comingOfAge
        case societyCritique
        case humanNature
        case perseverance
        case redemption
        case isolation
        case ambition
        case love
        case death
        case war
        case family
    }
}

class CuratedBookDatabase {
    static let shared = CuratedBookDatabase()
    
    private let bookProfiles: [String: BookProfile]
    private let allRecommendations: [BookProfile]
    
    private init() {
        var profiles: [String: BookProfile] = [:]
        var recommendations: [BookProfile] = []
        
        // Classic Literature Profiles
        let gatsbyProfile = BookProfile(
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            era: .earlyModern,
            style: [.literary, .symbolism, .conciseProse, .modernist],
            themes: [.americanDream, .love, .classStruggle, .identity, .innocenceLost],
            recommendations: ["Of Mice and Men", "The Sun Also Rises", "Tender Is the Night", "The Age of Innocence", "A Farewell to Arms"]
        )
        profiles["the great gatsby"] = gatsbyProfile
        
        let huckFinnProfile = BookProfile(
            title: "Adventures of Huckleberry Finn",
            author: "Mark Twain",
            era: .nineteenth,
            style: [.adventure, .strongVoice, .socialCommentary, .satirical, .comingOfAge],
            themes: [.freedom, .moralGrowth, .friendship, .societyCritique, .comingOfAge, .justice],
            recommendations: ["To Kill a Mockingbird", "The Adventures of Tom Sawyer", "Of Mice and Men", "A Connecticut Yankee in King Arthur's Court", "The Catcher in the Rye"]
        )
        profiles["adventures of huckleberry finn"] = huckFinnProfile
        profiles["the adventures of huckleberry finn"] = huckFinnProfile
        profiles["huckleberry finn"] = huckFinnProfile
        
        let treasureIslandProfile = BookProfile(
            title: "Treasure Island",
            author: "Robert Louis Stevenson",
            era: .nineteenth,
            style: [.adventure, .strongVoice, .comingOfAge],
            themes: [.adventure, .comingOfAge, .moralGrowth, .survival],
            recommendations: ["The Call of the Wild", "Robinson Crusoe", "Kidnapped", "The Count of Monte Cristo", "20,000 Leagues Under the Sea"]
        )
        profiles["treasure island"] = treasureIslandProfile
        
        // Recommendation Pool - Books that make great recommendations
        recommendations = [
            // American Classics
            BookProfile(
                title: "Of Mice and Men",
                author: "John Steinbeck",
                era: .earlyModern,
                style: [.literary, .conciseProse, .realist, .symbolism],
                themes: [.friendship, .americanDream, .innocenceLost, .isolation],
                recommendations: []
            ),
            BookProfile(
                title: "The Old Man and the Sea",
                author: "Ernest Hemingway",
                era: .midCentury,
                style: [.literary, .conciseProse, .symbolism],
                themes: [.perseverance, .nature, .identity, .isolation, .survival],
                recommendations: []
            ),
            BookProfile(
                title: "To Kill a Mockingbird",
                author: "Harper Lee",
                era: .midCentury,
                style: [.literary, .strongVoice, .comingOfAge, .socialCommentary],
                themes: [.justice, .moralGrowth, .innocenceLost, .societyCritique, .comingOfAge],
                recommendations: []
            ),
            BookProfile(
                title: "The Catcher in the Rye",
                author: "J.D. Salinger",
                era: .midCentury,
                style: [.literary, .strongVoice, .comingOfAge],
                themes: [.identity, .innocenceLost, .isolation, .comingOfAge],
                recommendations: []
            ),
            BookProfile(
                title: "Lord of the Flies",
                author: "William Golding",
                era: .midCentury,
                style: [.literary, .adventure, .symbolism, .philosophical],
                themes: [.humanNature, .survival, .societyCritique, .innocenceLost],
                recommendations: []
            ),
            BookProfile(
                title: "The Call of the Wild",
                author: "Jack London",
                era: .earlyModern,
                style: [.adventure, .naturalist, .literary],
                themes: [.survival, .nature, .freedom, .identity],
                recommendations: []
            ),
            BookProfile(
                title: "The Grapes of Wrath",
                author: "John Steinbeck",
                era: .earlyModern,
                style: [.literary, .realist, .socialCommentary],
                themes: [.family, .perseverance, .americanDream, .societyCritique],
                recommendations: []
            ),
            // British/European Classics
            BookProfile(
                title: "The Count of Monte Cristo",
                author: "Alexandre Dumas",
                era: .nineteenth,
                style: [.adventure, .romantic],
                themes: [.redemption, .justice, .ambition, .love],
                recommendations: []
            ),
            BookProfile(
                title: "Robinson Crusoe",
                author: "Daniel Defoe",
                era: .classical,
                style: [.adventure, .realist],
                themes: [.survival, .isolation, .perseverance, .nature],
                recommendations: []
            ),
            BookProfile(
                title: "A Tale of Two Cities",
                author: "Charles Dickens",
                era: .nineteenth,
                style: [.literary, .romantic, .socialCommentary],
                themes: [.redemption, .love, .societyCritique, .death],
                recommendations: []
            ),
            BookProfile(
                title: "Great Expectations",
                author: "Charles Dickens",
                era: .nineteenth,
                style: [.literary, .comingOfAge, .socialCommentary],
                themes: [.ambition, .identity, .classStruggle, .love, .comingOfAge],
                recommendations: []
            ),
            BookProfile(
                title: "Jane Eyre",
                author: "Charlotte Brontë",
                era: .nineteenth,
                style: [.literary, .gothic, .romantic, .strongVoice],
                themes: [.identity, .love, .classStruggle, .moralGrowth],
                recommendations: []
            ),
            BookProfile(
                title: "Wuthering Heights",
                author: "Emily Brontë",
                era: .nineteenth,
                style: [.literary, .gothic, .romantic],
                themes: [.love, .death, .isolation, .nature],
                recommendations: []
            ),
            BookProfile(
                title: "1984",
                author: "George Orwell",
                era: .midCentury,
                style: [.literary, .philosophical, .socialCommentary],
                themes: [.freedom, .societyCritique, .identity, .love],
                recommendations: []
            ),
            BookProfile(
                title: "Animal Farm",
                author: "George Orwell",
                era: .midCentury,
                style: [.literary, .satirical, .philosophical, .conciseProse],
                themes: [.societyCritique, .freedom, .humanNature],
                recommendations: []
            ),
            BookProfile(
                title: "Heart of Darkness",
                author: "Joseph Conrad",
                era: .earlyModern,
                style: [.literary, .symbolism, .modernist],
                themes: [.humanNature, .adventure, .identity, .societyCritique],
                recommendations: []
            ),
            // Adventure Classics
            BookProfile(
                title: "The Hobbit",
                author: "J.R.R. Tolkien",
                era: .earlyModern,
                style: [.adventure, .comingOfAge, .humorous],
                themes: [.adventure, .comingOfAge, .friendship, .moralGrowth],
                recommendations: []
            ),
            BookProfile(
                title: "20,000 Leagues Under the Sea",
                author: "Jules Verne",
                era: .nineteenth,
                style: [.adventure],
                themes: [.adventure, .nature, .isolation],
                recommendations: []
            ),
            BookProfile(
                title: "The Three Musketeers",
                author: "Alexandre Dumas",
                era: .nineteenth,
                style: [.adventure, .romantic],
                themes: [.friendship, .adventure, .love, .ambition],
                recommendations: []
            ),
            BookProfile(
                title: "Moby-Dick",
                author: "Herman Melville",
                era: .nineteenth,
                style: [.literary, .adventure, .symbolism, .philosophical],
                themes: [.nature, .ambition, .identity, .death],
                recommendations: []
            ),
            BookProfile(
                title: "White Fang",
                author: "Jack London",
                era: .earlyModern,
                style: [.adventure, .naturalist],
                themes: [.survival, .nature, .identity],
                recommendations: []
            ),
            BookProfile(
                title: "Kidnapped",
                author: "Robert Louis Stevenson",
                era: .nineteenth,
                style: [.adventure, .comingOfAge],
                themes: [.adventure, .comingOfAge, .survival, .friendship],
                recommendations: []
            ),
            // Modern Literary
            BookProfile(
                title: "The Sun Also Rises",
                author: "Ernest Hemingway",
                era: .earlyModern,
                style: [.literary, .modernist, .conciseProse],
                themes: [.love, .identity, .innocenceLost],
                recommendations: []
            ),
            BookProfile(
                title: "A Farewell to Arms",
                author: "Ernest Hemingway",
                era: .earlyModern,
                style: [.literary, .modernist, .conciseProse],
                themes: [.war, .love, .death, .identity],
                recommendations: []
            ),
            BookProfile(
                title: "Life of Pi",
                author: "Yann Martel",
                era: .contemporary,
                style: [.literary, .adventure, .symbolism, .philosophical],
                themes: [.survival, .nature, .identity, .perseverance],
                recommendations: []
            ),
            BookProfile(
                title: "East of Eden",
                author: "John Steinbeck",
                era: .midCentury,
                style: [.literary, .realist, .symbolism],
                themes: [.family, .moralGrowth, .americanDream, .identity],
                recommendations: []
            ),
            BookProfile(
                title: "Brave New World",
                author: "Aldous Huxley",
                era: .earlyModern,
                style: [.literary, .philosophical, .satirical],
                themes: [.societyCritique, .freedom, .identity, .humanNature],
                recommendations: []
            ),
            BookProfile(
                title: "Fahrenheit 451",
                author: "Ray Bradbury",
                era: .midCentury,
                style: [.literary, .philosophical, .conciseProse],
                themes: [.societyCritique, .freedom, .identity],
                recommendations: []
            ),
            BookProfile(
                title: "The Pearl",
                author: "John Steinbeck",
                era: .midCentury,
                style: [.literary, .conciseProse, .symbolism],
                themes: [.ambition, .family, .innocenceLost],
                recommendations: []
            ),
            BookProfile(
                title: "The Outsiders",
                author: "S.E. Hinton",
                era: .midCentury,
                style: [.literary, .comingOfAge, .strongVoice],
                themes: [.classStruggle, .friendship, .identity, .comingOfAge],
                recommendations: []
            )
        ]
        
        self.bookProfiles = profiles
        self.allRecommendations = recommendations
    }
    
    func getProfile(for title: String) -> BookProfile? {
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return bookProfiles[normalizedTitle]
    }
    
    func findBestMatches(for selectedBooks: [BookProfile], excludeTitles: Set<String>, limit: Int = 3) -> [(book: BookProfile, score: Double, reason: String)] {
        let excludeTitlesLower = Set(excludeTitles.map { $0.lowercased() })
        
        let combinedStyles = selectedBooks.reduce(into: Set<BookProfile.LiteraryStyle>()) { $0.formUnion($1.style) }
        let combinedThemes = selectedBooks.reduce(into: Set<BookProfile.Theme>()) { $0.formUnion($1.themes) }
        let eras = selectedBooks.map { $0.era }
        
        var scoredBooks: [(book: BookProfile, score: Double, reason: String)] = []
        
        for candidate in allRecommendations {
            let candidateTitleLower = candidate.title.lowercased()
            if excludeTitlesLower.contains(candidateTitleLower) {
                continue
            }
            
            var score: Double = 0
            var reasons: [String] = []
            
            // Direct recommendations (highest weight)
            for selected in selectedBooks {
                if selected.recommendations.map({ $0.lowercased() }).contains(candidateTitleLower) {
                    score += 3.0
                    reasons.append("Recommended for fans of \(selected.title)")
                }
            }
            
            // Era matching (important for classics)
            let eraScore = calculateEraScore(candidate: candidate.era, selectedEras: eras)
            score += eraScore * 1.5
            if eraScore > 0.5 {
                reasons.append("From a similar literary period")
            }
            
            // Style overlap
            let styleOverlap = candidate.style.intersection(combinedStyles)
            let styleScore = Double(styleOverlap.count) / Double(max(candidate.style.count, 1))
            score += styleScore * 2.0
            if styleOverlap.contains(.literary) && combinedStyles.contains(.literary) {
                reasons.append("Literary classic")
            }
            if styleOverlap.contains(.adventure) && combinedStyles.contains(.adventure) {
                reasons.append("Adventure narrative")
            }
            if styleOverlap.contains(.comingOfAge) && combinedStyles.contains(.comingOfAge) {
                reasons.append("Coming-of-age story")
            }
            
            // Theme overlap
            let themeOverlap = candidate.themes.intersection(combinedThemes)
            let themeScore = Double(themeOverlap.count) / Double(max(candidate.themes.count, 1))
            score += themeScore * 2.5
            
            // Author diversity bonus (slight penalty for same author)
            let selectedAuthors = Set(selectedBooks.map { $0.author.lowercased() })
            if selectedAuthors.contains(candidate.author.lowercased()) {
                score -= 0.5
            }
            
            let primaryReason = reasons.first ?? "Matches your reading preferences"
            scoredBooks.append((candidate, score, primaryReason))
        }
        
        scoredBooks.sort { $0.score > $1.score }
        
        return Array(scoredBooks.prefix(limit))
    }
    
    private func calculateEraScore(candidate: BookProfile.BookEra, selectedEras: [BookProfile.BookEra]) -> Double {
        let eraOrder: [BookProfile.BookEra] = [.classical, .nineteenth, .earlyModern, .midCentury, .contemporary]
        
        guard let candidateIndex = eraOrder.firstIndex(of: candidate) else { return 0 }
        
        var totalScore: Double = 0
        for era in selectedEras {
            if let selectedIndex = eraOrder.firstIndex(of: era) {
                let distance = abs(candidateIndex - selectedIndex)
                totalScore += max(0, 1.0 - Double(distance) * 0.3)
            }
        }
        
        return totalScore / Double(max(selectedEras.count, 1))
    }
    
    func createProfileFromDocument(title: String, author: String?, subjects: String?) -> BookProfile {
        var inferredStyles: Set<BookProfile.LiteraryStyle> = []
        var inferredThemes: Set<BookProfile.Theme> = []
        var inferredEra: BookProfile.BookEra = .contemporary
        
        let subjectList = (subjects ?? "").lowercased()
        
        // Infer styles from subjects
        if subjectList.contains("adventure") { inferredStyles.insert(.adventure) }
        if subjectList.contains("classic") || subjectList.contains("literary") { inferredStyles.insert(.literary) }
        if subjectList.contains("coming of age") || subjectList.contains("bildungsroman") { inferredStyles.insert(.comingOfAge) }
        if subjectList.contains("satir") { inferredStyles.insert(.satirical) }
        if subjectList.contains("gothic") { inferredStyles.insert(.gothic) }
        if subjectList.contains("humor") || subjectList.contains("comedy") { inferredStyles.insert(.humorous) }
        
        // Infer themes from subjects
        if subjectList.contains("friendship") { inferredThemes.insert(.friendship) }
        if subjectList.contains("survival") { inferredThemes.insert(.survival) }
        if subjectList.contains("love") || subjectList.contains("romance") { inferredThemes.insert(.love) }
        if subjectList.contains("adventure") { inferredThemes.insert(.adventure) }
        if subjectList.contains("justice") { inferredThemes.insert(.justice) }
        if subjectList.contains("identity") { inferredThemes.insert(.identity) }
        if subjectList.contains("nature") || subjectList.contains("wilderness") { inferredThemes.insert(.nature) }
        if subjectList.contains("moral") { inferredThemes.insert(.moralGrowth) }
        if subjectList.contains("social") || subjectList.contains("society") { inferredThemes.insert(.societyCritique) }
        if subjectList.contains("family") { inferredThemes.insert(.family) }
        if subjectList.contains("war") { inferredThemes.insert(.war) }
        if subjectList.contains("death") { inferredThemes.insert(.death) }
        
        // Infer era
        if subjectList.contains("19th century") || subjectList.contains("1800") { inferredEra = .nineteenth }
        else if subjectList.contains("20th century") || subjectList.contains("1900") { inferredEra = .earlyModern }
        else if subjectList.contains("classic") { inferredEra = .nineteenth }
        
        // Default styles if none inferred
        if inferredStyles.isEmpty { inferredStyles = [.literary] }
        if inferredThemes.isEmpty { inferredThemes = [.adventure] }
        
        return BookProfile(
            title: title,
            author: author ?? "Unknown",
            era: inferredEra,
            style: inferredStyles,
            themes: inferredThemes,
            recommendations: []
        )
    }
}
