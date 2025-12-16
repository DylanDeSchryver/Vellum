import SwiftUI

struct AIRecommendationView: View {
    @EnvironmentObject var libraryController: LibraryController
    @StateObject private var recommendationService = BookRecommendationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDocuments: Set<UUID> = []
    @State private var currentStep: Step = .selection
    @State private var recommendations: [BookRecommendationService.BookRecommendation] = []
    
    enum Step {
        case selection
        case processing
        case results
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch currentStep {
                case .selection:
                    bookSelectionView
                case .processing:
                    processingView
                case .results:
                    resultsView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if currentStep == .selection {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Analyze") {
                            analyzeBooks()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedDocuments.isEmpty)
                    }
                }
                
                if currentStep == .results {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case .selection:
            return "Select Books"
        case .processing:
            return "Analyzing..."
        case .results:
            return "Recommendations"
        }
    }
    
    // MARK: - Book Selection View
    
    private var bookSelectionView: some View {
        VStack(spacing: 0) {
            SelectionHeaderView(
                selectedCount: selectedDocuments.count,
                totalCount: libraryController.documents.count
            )
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(libraryController.documents, id: \.id) { document in
                        SelectableBookRow(
                            document: document,
                            isSelected: selectedDocuments.contains(document.id ?? UUID())
                        )
                        .onTapGesture {
                            toggleSelection(for: document)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "brain")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse)
            }
            
            VStack(spacing: 8) {
                Text("Analyzing Your Books")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Finding patterns and themes in your selections...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            ProgressView()
                .scaleEffect(1.2)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                ResultsHeaderView(selectedCount: selectedDocuments.count)
                
                if recommendations.isEmpty {
                    EmptyRecommendationsView()
                } else {
                    VStack(spacing: 16) {
                        ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, recommendation in
                            RecommendationCard(
                                recommendation: recommendation,
                                rank: index + 1
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                TipView()
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelection(for document: Document) {
        guard let id = document.id else { return }
        
        if selectedDocuments.contains(id) {
            selectedDocuments.remove(id)
        } else {
            selectedDocuments.insert(id)
        }
    }
    
    private func analyzeBooks() {
        currentStep = .processing
        
        let selected = libraryController.documents.filter { doc in
            guard let id = doc.id else { return false }
            return selectedDocuments.contains(id)
        }
        
        Task {
            let results = await recommendationService.generateRecommendations(
                from: selected,
                allDocuments: libraryController.documents
            )
            
            await MainActor.run {
                recommendations = results
                currentStep = .results
            }
        }
    }
}

// MARK: - Selection Header View

struct SelectionHeaderView: View {
    let selectedCount: Int
    let totalCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Book Recommendations")
                        .font(.headline)
                    
                    Text("Select books you enjoy to get personalized suggestions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                Text("\(selectedCount) of \(totalCount) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if selectedCount > 0 {
                    Text("Ready to analyze")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Selectable Book Row

struct SelectableBookRow: View {
    let document: Document
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            
            ZStack {
                if let coverData = document.coverImage,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.2))
                    Image(systemName: "book.closed")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 45, height: 65)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title ?? "Untitled")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let author = document.author, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(isSelected ? Color.accentColor.opacity(0.05) : Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

// MARK: - Results Header View

struct ResultsHeaderView: View {
    let selectedCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 4) {
                Text("Analysis Complete!")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Based on \(selectedCount) book\(selectedCount == 1 ? "" : "s") you selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: BookRecommendationService.BookRecommendation
    let rank: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 32, height: 32)
                    
                    Text("#\(rank)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let author = recommendation.author {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                MatchBadge(score: recommendation.similarityScore)
            }
            
            Text(recommendation.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 44)
            
            HStack {
                Spacer()
                
                SearchButton(query: recommendation.searchQuery)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow.opacity(0.9)
        case 2: return .gray.opacity(0.7)
        case 3: return .orange.opacity(0.7)
        default: return .accentColor
        }
    }
}

// MARK: - Match Badge

struct MatchBadge: View {
    let score: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.caption2)
            
            Text("\(Int(score * 100))%")
                .font(.caption.bold())
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var badgeColor: Color {
        if score >= 0.8 {
            return .green
        } else if score >= 0.6 {
            return .blue
        } else if score >= 0.4 {
            return .orange
        } else {
            return .secondary
        }
    }
}

// MARK: - Search Button

struct SearchButton: View {
    let query: String
    
    var body: some View {
        Link(destination: searchURL) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                
                Text("Search")
                    .font(.caption.bold())
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    private var searchURL: URL {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/search?q=\(encodedQuery)+book")!
    }
}

// MARK: - Empty Recommendations View

struct EmptyRecommendationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Similar Books Found")
                    .font(.headline)
                
                Text("Try selecting more books or books with different themes to get better recommendations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}

// MARK: - Tip View

struct TipView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Pro Tip")
                    .font(.caption.bold())
                
                Text("Tap 'Search' to find these books online or check if they're available on Project Gutenberg in the Discover tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    AIRecommendationView()
        .environmentObject(LibraryController.shared)
}
