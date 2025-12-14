import SwiftUI

struct CollectionsView: View {
    @EnvironmentObject var libraryController: LibraryController
    @State private var showingNewCollection = false
    @State private var newCollectionName = ""
    @State private var selectedIcon = "folder"
    @State private var selectedCollection: Collection?
    
    private let iconOptions = [
        "folder", "folder.fill", "star", "heart", "bookmark",
        "book", "books.vertical", "text.book.closed", "graduationcap",
        "briefcase", "archivebox", "tray.full"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Favorites Section
                    if !libraryController.favoriteDocuments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                Text("Favorites")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(libraryController.favoriteDocuments, id: \.id) { document in
                                        CompactDocumentCard(document: document)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Collections Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Collections")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button {
                                showingNewCollection = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal)
                        
                        if libraryController.collections.isEmpty {
                            EmptyCollectionsView {
                                showingNewCollection = true
                            }
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(libraryController.collections, id: \.id) { collection in
                                    NavigationLink {
                                        CollectionDetailView(collection: collection)
                                    } label: {
                                        CollectionRow(collection: collection)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Collections")
            .sheet(isPresented: $showingNewCollection) {
                NewCollectionSheet(
                    name: $newCollectionName,
                    selectedIcon: $selectedIcon,
                    iconOptions: iconOptions
                ) {
                    if !newCollectionName.isEmpty {
                        libraryController.createCollection(name: newCollectionName, icon: selectedIcon)
                        newCollectionName = ""
                        selectedIcon = "folder"
                    }
                }
            }
        }
    }
}

// MARK: - Collection Row

struct CollectionRow: View {
    let collection: Collection
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: collection.icon ?? "folder")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name ?? "Untitled")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("\(documentCount) books")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var documentCount: Int {
        (collection.documents as? Set<Document>)?.count ?? 0
    }
}

// MARK: - Collection Detail View

struct CollectionDetailView: View {
    let collection: Collection
    @EnvironmentObject var libraryController: LibraryController
    @State private var showingAddDocuments = false
    @State private var showingReader = false
    @State private var selectedDocument: Document?
    
    private var documents: [Document] {
        (collection.documents as? Set<Document>)?.sorted { ($0.title ?? "") < ($1.title ?? "") } ?? []
    }
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            if documents.isEmpty {
                VStack(spacing: 20) {
                    Spacer(minLength: 60)
                    
                    Image(systemName: collection.icon ?? "folder")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    Text("No books in this collection")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        showingAddDocuments = true
                    } label: {
                        Label("Add Books", systemImage: "plus.circle.fill")
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
            } else {
                LazyVGrid(columns: gridColumns, spacing: 20) {
                    ForEach(documents, id: \.id) { document in
                        DocumentGridItem(document: document)
                            .onTapGesture {
                                selectedDocument = document
                                libraryController.openDocument(document)
                                showingReader = true
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    libraryController.removeFromCollection(document, collection: collection)
                                } label: {
                                    Label("Remove from Collection", systemImage: "minus.circle")
                                }
                            }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(collection.name ?? "Collection")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddDocuments = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddDocuments) {
            AddToCollectionSheet(collection: collection)
        }
        .fullScreenCover(isPresented: $showingReader) {
            if let document = selectedDocument {
                ReaderView(document: document)
            }
        }
    }
}

// MARK: - Add to Collection Sheet

struct AddToCollectionSheet: View {
    let collection: Collection
    @EnvironmentObject var libraryController: LibraryController
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDocuments: Set<UUID> = []
    
    private var availableDocuments: [Document] {
        let existingIds = (collection.documents as? Set<Document>)?.compactMap { $0.id } ?? []
        return libraryController.documents.filter { doc in
            guard let id = doc.id else { return false }
            return !existingIds.contains(id)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if availableDocuments.isEmpty {
                    Text("All books are already in this collection")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableDocuments, id: \.id) { document in
                        Button {
                            if let id = document.id {
                                if selectedDocuments.contains(id) {
                                    selectedDocuments.remove(id)
                                } else {
                                    selectedDocuments.insert(id)
                                }
                            }
                        } label: {
                            HStack {
                                if let coverData = document.coverImage,
                                   let uiImage = UIImage(data: coverData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 40, height: 56)
                                        .overlay(
                                            Image(systemName: "doc.text")
                                                .foregroundStyle(Color.accentColor)
                                        )
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(document.title ?? "Untitled")
                                        .foregroundStyle(.primary)
                                    if let author = document.author {
                                        Text(author)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if let id = document.id, selectedDocuments.contains(id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        for document in availableDocuments {
                            if let id = document.id, selectedDocuments.contains(id) {
                                libraryController.addToCollection(document, collection: collection)
                            }
                        }
                        dismiss()
                    }
                    .disabled(selectedDocuments.isEmpty)
                }
            }
        }
    }
}

// MARK: - New Collection Sheet

struct NewCollectionSheet: View {
    @Binding var name: String
    @Binding var selectedIcon: String
    let iconOptions: [String]
    let onCreate: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Collection Name") {
                    TextField("Enter name", text: $name)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 16) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == icon ? Color.accentColor : Color(.systemGray5))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        onCreate()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Compact Document Card

struct CompactDocumentCard: View {
    let document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let coverData = document.coverImage,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                    Image(systemName: "book")
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 100, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            
            Text(document.title ?? "Untitled")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}

// MARK: - Empty Collections View

struct EmptyCollectionsView: View {
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.secondary.opacity(0.5))
            
            VStack(spacing: 6) {
                Text("No Collections Yet")
                    .font(.headline)
                
                Text("Create collections to organize your reading")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                onCreate()
            } label: {
                Label("Create Collection", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CollectionsView()
        .environmentObject(LibraryController.shared)
}
