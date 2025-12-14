import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var libraryController: LibraryController
    @StateObject private var gutenbergService = GutenbergService.shared
    
    @State private var searchText = ""
    @State private var showingDownloadSuccess = false
    @State private var downloadedBookTitle = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search Project Gutenberg...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            gutenbergService.searchResults = []
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
                if gutenbergService.isDownloading {
                    downloadingView
                } else if gutenbergService.isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !searchText.isEmpty && !gutenbergService.searchResults.isEmpty {
                    searchResultsView
                } else if !searchText.isEmpty && gutenbergService.searchResults.isEmpty {
                    emptySearchView
                } else {
                    popularBooksView
                }
            }
            .navigationTitle("Discover")
            .alert("Book Added!", isPresented: $showingDownloadSuccess) {
                Button("OK") { }
            } message: {
                Text("\"\(downloadedBookTitle)\" has been added to your library.")
            }
            .alert("Error", isPresented: .constant(gutenbergService.error != nil)) {
                Button("OK") {
                    gutenbergService.error = nil
                }
            } message: {
                if let error = gutenbergService.error {
                    Text(error)
                }
            }
        }
        .task {
            if gutenbergService.popularBooks.isEmpty {
                await gutenbergService.loadPopularBooks()
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(gutenbergService.searchResults) { book in
                    BookRowView(book: book) {
                        Task {
                            await downloadAndImport(book)
                        }
                    }
                    Divider()
                        .padding(.leading, 100)
                }
            }
        }
    }
    
    // MARK: - Popular Books
    
    private var popularBooksView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                                await downloadAndImport(book)
                            }
                        }
                        Divider()
                            .padding(.leading, 100)
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
            
            if let title = gutenbergService.currentDownloadTitle {
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
            await gutenbergService.search(query: searchText)
        }
    }
    
    private func downloadAndImport(_ book: GutenbergBook) async {
        // Download the EPUB
        guard let fileURL = await gutenbergService.downloadBook(book) else {
            return
        }
        
        // Download cover image
        let coverData = await gutenbergService.downloadCoverImage(book)
        
        // Import to library
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

#Preview {
    DiscoverView()
        .environmentObject(LibraryController.shared)
}
