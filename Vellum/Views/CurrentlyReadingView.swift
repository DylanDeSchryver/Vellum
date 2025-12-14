import SwiftUI

struct CurrentlyReadingView: View {
    @EnvironmentObject var libraryController: LibraryController
    @State private var showingReader = false
    @State private var selectedDocument: Document?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if libraryController.recentDocuments.isEmpty {
                        EmptyReadingView()
                    } else {
                        // Currently Reading (most recent)
                        if let current = libraryController.recentDocuments.first {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Continue Reading")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal)
                                
                                CurrentReadingCard(document: current) {
                                    openDocument(current)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Reading Stats
                        ReadingStatsSection()
                            .padding(.horizontal)
                        
                        // Recently Read
                        if libraryController.recentDocuments.count > 1 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recently Read")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(Array(libraryController.recentDocuments.dropFirst()), id: \.id) { document in
                                        RecentDocumentRow(document: document)
                                            .onTapGesture {
                                                openDocument(document)
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reading")
            .fullScreenCover(isPresented: $showingReader) {
                if let document = selectedDocument {
                    ReaderView(document: document)
                }
            }
        }
    }
    
    private func openDocument(_ document: Document) {
        selectedDocument = document
        libraryController.openDocument(document)
        showingReader = true
    }
}

// MARK: - Current Reading Card

struct CurrentReadingCard: View {
    let document: Document
    let onContinue: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Cover
            ZStack {
                if let coverData = document.coverImage,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: "book")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 100, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            
            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(document.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(2)
                
                if let author = document.author, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Progress
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(Int(document.readingProgress * 100))% complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if document.pageCount > 0 {
                            Text("Page \(document.currentPage + 1) of \(document.pageCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor)
                                .frame(width: geo.size.width * document.readingProgress)
                        }
                    }
                    .frame(height: 6)
                }
                
                Button {
                    onContinue()
                } label: {
                    HStack {
                        Image(systemName: "book.fill")
                        Text("Continue Reading")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Reading Stats Section

struct ReadingStatsSection: View {
    @EnvironmentObject var libraryController: LibraryController
    
    private var totalBooks: Int {
        libraryController.documents.count
    }
    
    private var completedBooks: Int {
        libraryController.documents.filter { $0.readingProgress >= 0.95 }.count
    }
    
    private var inProgressBooks: Int {
        libraryController.documents.filter { $0.readingProgress > 0 && $0.readingProgress < 0.95 }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading Stats")
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                StatCard(title: "Library", value: "\(totalBooks)", icon: "books.vertical", color: .blue)
                StatCard(title: "In Progress", value: "\(inProgressBooks)", icon: "book", color: .orange)
                StatCard(title: "Completed", value: "\(completedBooks)", icon: "checkmark.circle", color: .green)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Recent Document Row

struct RecentDocumentRow: View {
    let document: Document
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover thumbnail
            ZStack {
                if let coverData = document.coverImage,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.2))
                    Image(systemName: "book")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 50, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title ?? "Untitled")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let author = document.author, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray5))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * document.readingProgress)
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(document.readingProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accentColor)
                
                if let lastOpened = document.lastOpened {
                    Text(timeAgo(from: lastOpened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Empty Reading View

struct EmptyReadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 80)
            
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Reading Activity")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Open a book from your library to start reading")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}

#Preview {
    CurrentlyReadingView()
        .environmentObject(LibraryController.shared)
}
