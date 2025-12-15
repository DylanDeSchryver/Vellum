import SwiftUI

enum BookSource: String, CaseIterable {
    case gutenberg = "Project Gutenberg"
    case standardEbooks = "Standard Ebooks"
}

struct DiscoverView: View {
    @EnvironmentObject var libraryController: LibraryController
    @StateObject private var gutenbergService = GutenbergService.shared
    @StateObject private var standardEbooksService = StandardEbooksService.shared
    
    @State private var searchText = ""
    @State private var showingDownloadSuccess = false
    @State private var downloadedBookTitle = ""
    @State private var selectedSource: BookSource = .gutenberg
    @State private var showingSourceInfo = false
    
    private var isSearching: Bool {
        selectedSource == .gutenberg ? gutenbergService.isSearching : standardEbooksService.isSearching
    }
    
    private var isDownloading: Bool {
        selectedSource == .gutenberg ? gutenbergService.isDownloading : standardEbooksService.isDownloading
    }
    
    private var currentError: String? {
        selectedSource == .gutenberg ? gutenbergService.error : standardEbooksService.error
    }
    
    private var downloadTitle: String? {
        selectedSource == .gutenberg ? gutenbergService.currentDownloadTitle : standardEbooksService.currentDownloadTitle
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Source Picker
                Picker("Source", selection: $selectedSource) {
                    ForEach(BookSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: selectedSource) { _, _ in
                    searchText = ""
                }
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search \(selectedSource.rawValue)...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            gutenbergService.searchResults = []
                            standardEbooksService.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Content
                if isDownloading {
                    downloadingView
                } else if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !searchText.isEmpty && hasSearchResults {
                    searchResultsView
                } else if !searchText.isEmpty && !hasSearchResults {
                    emptySearchView
                } else {
                    popularBooksView
                }
            }
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSourceInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSourceInfo) {
                SourceInfoSheet()
            }
            .alert("Book Added!", isPresented: $showingDownloadSuccess) {
                Button("OK") { }
            } message: {
                Text("\"\(downloadedBookTitle)\" has been added to your library.")
            }
            .alert("Error", isPresented: .constant(currentError != nil)) {
                Button("OK") {
                    gutenbergService.error = nil
                    standardEbooksService.error = nil
                }
            } message: {
                if let error = currentError {
                    Text(error)
                }
            }
        }
        .task {
            await loadInitialData()
        }
        .onChange(of: selectedSource) { _, _ in
            Task {
                await loadInitialData()
            }
        }
    }
    
    private var hasSearchResults: Bool {
        selectedSource == .gutenberg ? !gutenbergService.searchResults.isEmpty : !standardEbooksService.searchResults.isEmpty
    }
    
    private func loadInitialData() async {
        switch selectedSource {
        case .gutenberg:
            if gutenbergService.popularBooks.isEmpty {
                await gutenbergService.loadPopularBooks()
            }
        case .standardEbooks:
            if standardEbooksService.featuredBooks.isEmpty {
                await standardEbooksService.loadFeaturedBooks()
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch selectedSource {
                case .gutenberg:
                    ForEach(gutenbergService.searchResults) { book in
                        BookRowView(book: book) {
                            Task {
                                await downloadAndImportGutenberg(book)
                            }
                        }
                        Divider()
                            .padding(.leading, 100)
                    }
                case .standardEbooks:
                    ForEach(standardEbooksService.searchResults) { book in
                        StandardEbookRowView(book: book) {
                            Task {
                                await downloadAndImportStandardEbook(book)
                            }
                        }
                        Divider()
                            .padding(.leading, 100)
                    }
                }
            }
        }
    }
    
    // MARK: - Popular Books
    
    private var popularBooksView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch selectedSource {
                case .gutenberg:
                    Text("Popular Public Domain Books")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    Text("All books are free and in the public domain from Project Gutenberg.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(gutenbergService.popularBooks) { book in
                            BookRowView(book: book) {
                                Task {
                                    await downloadAndImportGutenberg(book)
                                }
                            }
                            Divider()
                                .padding(.leading, 100)
                        }
                    }
                    
                case .standardEbooks:
                    Text("New Releases")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    Text("Beautifully formatted public domain ebooks from Standard Ebooks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(standardEbooksService.featuredBooks) { book in
                            StandardEbookRowView(book: book) {
                                Task {
                                    await downloadAndImportStandardEbook(book)
                                }
                            }
                            Divider()
                                .padding(.leading, 100)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Search
    
    private var emptySearchView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("No books found")
                .font(.headline)
            
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Downloading View
    
    private var downloadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            if let title = downloadTitle {
                Text("Downloading...")
                    .font(.headline)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        Task {
            switch selectedSource {
            case .gutenberg:
                await gutenbergService.search(query: searchText)
            case .standardEbooks:
                await standardEbooksService.search(query: searchText)
            }
        }
    }
    
    private func downloadAndImportGutenberg(_ book: GutenbergBook) async {
        guard let fileURL = await gutenbergService.downloadBook(book) else {
            return
        }
        
        let coverData = await gutenbergService.downloadCoverImage(book)
        
        await MainActor.run {
            libraryController.importDownloadedBook(
                from: fileURL,
                title: book.title,
                author: book.authorName,
                coverImage: coverData
            )
            
            downloadedBookTitle = book.title
            showingDownloadSuccess = true
        }
    }
    
    private func downloadAndImportStandardEbook(_ book: StandardEbook) async {
        guard let fileURL = await standardEbooksService.downloadBook(book) else {
            return
        }
        
        let coverData = await standardEbooksService.downloadCoverImage(book)
        
        await MainActor.run {
            libraryController.importDownloadedBook(
                from: fileURL,
                title: book.title,
                author: book.authorName,
                coverImage: coverData
            )
            
            downloadedBookTitle = book.title
            showingDownloadSuccess = true
        }
    }
}

// MARK: - Standard Ebook Row View

struct StandardEbookRowView: View {
    let book: StandardEbook
    let onDownload: () -> Void
    
    @State private var coverImage: UIImage?
    
    var body: some View {
        HStack(spacing: 16) {
            // Cover Image
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color(.systemGray5)
                        Image(systemName: "book.closed.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 70, height: 100)
            .cornerRadius(6)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Book Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                    Text("Standard Ebooks")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                
                Spacer()
                
                // Download Button
                Button {
                    onDownload()
                } label: {
                    Label("Add to Library", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
            
            Spacer()
        }
        .padding()
        .task {
            await loadCover()
        }
    }
    
    private func loadCover() async {
        guard let url = book.coverURL else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.coverImage = image
                }
            }
        } catch {
            // Silently fail - we'll show placeholder
        }
    }
}

// MARK: - Source Info Sheet

struct SourceInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Book Sources")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Both sources offer free public domain ebooks. Here's how they differ:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)
                    
                    // Project Gutenberg
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "books.vertical.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .frame(width: 40)
                            
                            Text("Project Gutenberg")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoBullet(icon: "checkmark.circle.fill", color: .green, 
                                      text: "Largest collection (70,000+ books)")
                            InfoBullet(icon: "checkmark.circle.fill", color: .green,
                                      text: "Great for finding obscure titles")
                            InfoBullet(icon: "checkmark.circle.fill", color: .green,
                                      text: "Multiple languages available")
                            InfoBullet(icon: "minus.circle.fill", color: .orange,
                                      text: "Basic formatting, varies by book")
                            InfoBullet(icon: "minus.circle.fill", color: .orange,
                                      text: "Some books may have OCR errors")
                        }
                        .padding(.leading, 52)
                        
                        Text("Best for: Finding specific titles, rare books, non-English works")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 52)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Standard Ebooks
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.title2)
                                .foregroundStyle(.purple)
                                .frame(width: 40)
                            
                            Text("Standard Ebooks")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoBullet(icon: "checkmark.circle.fill", color: .green,
                                      text: "Professional typography & formatting")
                            InfoBullet(icon: "checkmark.circle.fill", color: .green,
                                      text: "Hand-proofread for accuracy")
                            InfoBullet(icon: "checkmark.circle.fill", color: .green,
                                      text: "Beautiful, consistent design")
                            InfoBullet(icon: "minus.circle.fill", color: .orange,
                                      text: "Smaller collection (~2,000 books)")
                            InfoBullet(icon: "minus.circle.fill", color: .orange,
                                      text: "English language only")
                        }
                        .padding(.leading, 52)
                        
                        Text("Best for: Classic literature, best reading experience")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 52)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Tip
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        
                        Text("Tip: If a book exists on both, Standard Ebooks usually has the better formatted version.")
                            .font(.callout)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Book Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoBullet: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    DiscoverView()
        .environmentObject(LibraryController.shared)
}
