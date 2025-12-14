import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject var libraryController: LibraryController
    @State private var showingImporter = false
    @State private var showingReader = false
    @State private var selectedDocument: Document?
    @State private var viewMode: ViewMode = .grid
    @State private var showingSortOptions = false
    
    enum ViewMode {
        case grid, list
    }
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Continue Reading Section
                    if !libraryController.recentDocuments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Continue Reading")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(libraryController.recentDocuments, id: \.id) { document in
                                        ContinueReadingCard(document: document)
                                            .onTapGesture {
                                                openDocument(document)
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Library Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Library")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Menu {
                                ForEach(LibraryController.SortOption.allCases, id: \.self) { option in
                                    Button {
                                        libraryController.sortOption = option
                                    } label: {
                                        HStack {
                                            Text(option.rawValue)
                                            if libraryController.sortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button {
                                withAnimation {
                                    viewMode = viewMode == .grid ? .list : .grid
                                }
                            } label: {
                                Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        if libraryController.filteredDocuments.isEmpty {
                            EmptyLibraryView {
                                showingImporter = true
                            }
                        } else {
                            if viewMode == .grid {
                                LazyVGrid(columns: gridColumns, spacing: 20) {
                                    ForEach(libraryController.filteredDocuments, id: \.id) { document in
                                        DocumentGridItem(document: document)
                                            .onTapGesture {
                                                openDocument(document)
                                            }
                                            .contextMenu {
                                                documentContextMenu(for: document)
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                LazyVStack(spacing: 1) {
                                    ForEach(libraryController.filteredDocuments, id: \.id) { document in
                                        DocumentListItem(document: document)
                                            .onTapGesture {
                                                openDocument(document)
                                            }
                                            .contextMenu {
                                                documentContextMenu(for: document)
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
            .navigationTitle("Vellum")
            .searchable(text: $libraryController.searchQuery, prompt: "Search books")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: LibraryController.supportedTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        libraryController.importDocument(from: url)
                    }
                case .failure(let error):
                    print("Import failed: \(error)")
                }
            }
            .fullScreenCover(isPresented: $showingReader) {
                if let document = selectedDocument {
                    ReaderView(document: document)
                }
            }
            .overlay {
                if libraryController.isImporting {
                    ImportingOverlay()
                }
            }
        }
    }
    
    private func openDocument(_ document: Document) {
        selectedDocument = document
        libraryController.openDocument(document)
        showingReader = true
    }
    
    @ViewBuilder
    private func documentContextMenu(for document: Document) -> some View {
        Button {
            libraryController.toggleFavorite(document)
        } label: {
            Label(
                document.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: document.isFavorite ? "heart.slash" : "heart"
            )
        }
        
        Button(role: .destructive) {
            libraryController.deleteDocument(document)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Document Grid Item

struct DocumentGridItem: View {
    let document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image
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
                    
                    VStack(spacing: 8) {
                        Image(systemName: documentIcon)
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.8))
                        
                        Text(document.title ?? "Untitled")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 8)
                    }
                }
                
                // Favorite badge
                if document.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.red)
                                .clipShape(Circle())
                                .padding(6)
                        }
                        Spacer()
                    }
                }
                
                // Progress indicator
                if document.readingProgress > 0 {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: geo.size.width * document.readingProgress, height: 3)
                        }
                        .frame(height: 3)
                    }
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Title and Author
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let author = document.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private var documentIcon: String {
        switch document.fileType?.lowercased() {
        case "pdf": return "doc.text"
        case "epub": return "book"
        case "txt": return "doc.plaintext"
        default: return "doc"
        }
    }
}

// MARK: - Document List Item

struct DocumentListItem: View {
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
                    Image(systemName: documentIcon)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 50, height: 70)
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
                
                HStack(spacing: 12) {
                    if document.readingProgress > 0 {
                        Text("\(Int(document.readingProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    
                    Text(formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if document.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var documentIcon: String {
        switch document.fileType?.lowercased() {
        case "pdf": return "doc.text"
        case "epub": return "book"
        case "txt": return "doc.plaintext"
        default: return "doc"
        }
    }
    
    private var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: document.fileSize)
    }
}

// MARK: - Continue Reading Card

struct ContinueReadingCard: View {
    let document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
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
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                // Progress bar
                VStack {
                    Spacer()
                    ProgressView(value: document.readingProgress)
                        .tint(.white)
                        .background(Color.black.opacity(0.3))
                }
            }
            .frame(width: 120, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title ?? "Untitled")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(Int(document.readingProgress * 100))% complete")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, alignment: .leading)
        }
    }
}

// MARK: - Empty Library View

struct EmptyLibraryView: View {
    let onImport: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Your Library is Empty")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Import PDFs and other documents to start reading")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                onImport()
            } label: {
                Label("Import Documents", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Importing Overlay

struct ImportingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                
                Text("Importing...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryController.shared)
}
