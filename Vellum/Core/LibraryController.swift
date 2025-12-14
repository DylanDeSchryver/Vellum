import SwiftUI
import PDFKit
import UniformTypeIdentifiers

class LibraryController: ObservableObject {
    static let shared = LibraryController()
    
    @Published var documents: [Document] = []
    @Published var recentDocuments: [Document] = []
    @Published var favoriteDocuments: [Document] = []
    @Published var collections: [Collection] = []
    @Published var isImporting = false
    @Published var importError: String?
    @Published var searchQuery = ""
    @Published var sortOption: SortOption = .dateAdded
    @Published var currentDocument: Document?
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case title = "Title"
        case author = "Author"
        case lastOpened = "Recently Read"
        case progress = "Progress"
    }
    
    private let coreDataManager = CoreDataManager.shared
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("VellumLibrary", isDirectory: true)
    }
    
    private init() {
        createLibraryDirectoryIfNeeded()
        loadDocuments()
        loadCollections()
    }
    
    private func createLibraryDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            do {
                try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create library directory: \(error)")
            }
        }
    }
    
    func loadDocuments() {
        documents = coreDataManager.fetchAllDocuments()
        recentDocuments = coreDataManager.fetchRecentDocuments()
        favoriteDocuments = coreDataManager.fetchFavoriteDocuments()
    }
    
    func loadCollections() {
        collections = coreDataManager.fetchAllCollections()
    }
    
    var filteredDocuments: [Document] {
        var result = documents
        
        if !searchQuery.isEmpty {
            result = result.filter { doc in
                let titleMatch = doc.title?.localizedCaseInsensitiveContains(searchQuery) ?? false
                let authorMatch = doc.author?.localizedCaseInsensitiveContains(searchQuery) ?? false
                return titleMatch || authorMatch
            }
        }
        
        switch sortOption {
        case .dateAdded:
            result.sort { ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast) }
        case .title:
            result.sort { ($0.title ?? "") < ($1.title ?? "") }
        case .author:
            result.sort { ($0.author ?? "") < ($1.author ?? "") }
        case .lastOpened:
            result.sort { ($0.lastOpened ?? Date.distantPast) > ($1.lastOpened ?? Date.distantPast) }
        case .progress:
            result.sort { $0.readingProgress > $1.readingProgress }
        }
        
        return result
    }
    
    // MARK: - Import
    
    func importDocument(from url: URL) {
        isImporting = true
        importError = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let fileName = url.lastPathComponent
                let destinationURL = self.documentsDirectory.appendingPathComponent(UUID().uuidString + "_" + fileName)
                
                try self.fileManager.copyItem(at: url, to: destinationURL)
                
                let attributes = try self.fileManager.attributesOfItem(atPath: destinationURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let fileType = url.pathExtension.lowercased()
                
                var title = url.deletingPathExtension().lastPathComponent
                var author: String?
                var pageCount: Int32 = 0
                var coverImage: Data?
                
                if fileType == "pdf" {
                    if let pdfDocument = PDFDocument(url: destinationURL) {
                        pageCount = Int32(pdfDocument.pageCount)
                        
                        if let metadata = pdfDocument.documentAttributes {
                            if let pdfTitle = metadata[PDFDocumentAttribute.titleAttribute] as? String, !pdfTitle.isEmpty {
                                title = pdfTitle
                            }
                            if let pdfAuthor = metadata[PDFDocumentAttribute.authorAttribute] as? String {
                                author = pdfAuthor
                            }
                        }
                        
                        if let firstPage = pdfDocument.page(at: 0) {
                            let pageRect = firstPage.bounds(for: .mediaBox)
                            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 280))
                            let image = renderer.image { context in
                                UIColor.white.setFill()
                                context.fill(CGRect(origin: .zero, size: CGSize(width: 200, height: 280)))
                                
                                context.cgContext.translateBy(x: 0, y: 280)
                                context.cgContext.scaleBy(x: 200 / pageRect.width, y: -280 / pageRect.height)
                                
                                if let cgImage = firstPage.thumbnail(of: CGSize(width: pageRect.width, height: pageRect.height), for: .mediaBox).cgImage {
                                    context.cgContext.draw(cgImage, in: pageRect)
                                }
                            }
                            coverImage = image.jpegData(compressionQuality: 0.7)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    _ = self.coreDataManager.createDocument(
                        title: title,
                        author: author,
                        filePath: destinationURL.path,
                        fileType: fileType,
                        fileSize: fileSize,
                        pageCount: pageCount,
                        coverImage: coverImage
                    )
                    self.loadDocuments()
                    self.isImporting = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.importError = error.localizedDescription
                    self.isImporting = false
                }
            }
        }
    }
    
    // MARK: - Import Downloaded Book (from Gutenberg)
    
    func importDownloadedBook(from url: URL, title: String, author: String, coverImage: Data?) {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let fileType = url.pathExtension.lowercased()
            
            _ = coreDataManager.createDocument(
                title: title,
                author: author,
                filePath: url.path,
                fileType: fileType,
                fileSize: fileSize,
                pageCount: 0,
                coverImage: coverImage
            )
            
            loadDocuments()
        } catch {
            print("Failed to import downloaded book: \(error)")
            importError = error.localizedDescription
        }
    }
    
    // MARK: - Document Actions
    
    func deleteDocument(_ document: Document) {
        if let filePath = document.filePath {
            try? fileManager.removeItem(atPath: filePath)
        }
        coreDataManager.delete(document)
        loadDocuments()
    }
    
    func toggleFavorite(_ document: Document) {
        document.isFavorite.toggle()
        coreDataManager.save()
        loadDocuments()
    }
    
    func updateProgress(for document: Document, page: Int32, progress: Double) {
        coreDataManager.updateReadingProgress(for: document, page: page, progress: progress)
        loadDocuments()
    }
    
    func openDocument(_ document: Document) {
        document.lastOpened = Date()
        coreDataManager.save()
        currentDocument = document
        loadDocuments()
    }
    
    // MARK: - Collections
    
    func createCollection(name: String, icon: String = "folder") {
        _ = coreDataManager.createCollection(name: name, icon: icon)
        loadCollections()
    }
    
    func deleteCollection(_ collection: Collection) {
        coreDataManager.delete(collection)
        loadCollections()
    }
    
    func addToCollection(_ document: Document, collection: Collection) {
        coreDataManager.addDocument(document, to: collection)
        loadCollections()
    }
    
    func removeFromCollection(_ document: Document, collection: Collection) {
        coreDataManager.removeDocument(document, from: collection)
        loadCollections()
    }
    
    // MARK: - Supported Types
    
    static var supportedTypes: [UTType] {
        [.pdf, .epub, .plainText, .rtf]
    }
    
    static var supportedExtensions: [String] {
        ["pdf", "epub", "txt", "rtf"]
    }
}

extension UTType {
    static var epub: UTType {
        UTType(filenameExtension: "epub") ?? .data
    }
}
