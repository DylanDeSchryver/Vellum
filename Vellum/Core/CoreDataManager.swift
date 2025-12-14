import CoreData
import SwiftUI

class CoreDataManager {
    static let shared = CoreDataManager()
    
    let persistentContainer: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "VellumModel")
        
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
    
    func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
        save()
    }
    
    // MARK: - Document Operations
    
    func createDocument(
        title: String,
        author: String?,
        filePath: String,
        fileType: String,
        fileSize: Int64,
        pageCount: Int32,
        coverImage: Data?
    ) -> Document {
        let document = Document(context: viewContext)
        document.id = UUID()
        document.title = title
        document.author = author
        document.filePath = filePath
        document.fileType = fileType
        document.fileSize = fileSize
        document.pageCount = pageCount
        document.coverImage = coverImage
        document.dateAdded = Date()
        document.lastOpened = nil
        document.currentPage = 0
        document.readingProgress = 0.0
        document.isFavorite = false
        
        save()
        return document
    }
    
    func fetchAllDocuments() -> [Document] {
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Document.dateAdded, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch documents: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchRecentDocuments(limit: Int = 5) -> [Document] {
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Document.lastOpened, ascending: false)]
        request.predicate = NSPredicate(format: "lastOpened != nil")
        request.fetchLimit = limit
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch recent documents: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchFavoriteDocuments() -> [Document] {
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Document.title, ascending: true)]
        request.predicate = NSPredicate(format: "isFavorite == YES")
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch favorite documents: \(error.localizedDescription)")
            return []
        }
    }
    
    func updateReadingProgress(for document: Document, page: Int32, progress: Double) {
        document.currentPage = page
        document.readingProgress = progress
        document.lastOpened = Date()
        save()
    }
    
    // MARK: - Collection Operations
    
    func createCollection(name: String, icon: String = "folder") -> Collection {
        let collection = Collection(context: viewContext)
        collection.id = UUID()
        collection.name = name
        collection.icon = icon
        collection.dateCreated = Date()
        
        save()
        return collection
    }
    
    func fetchAllCollections() -> [Collection] {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Collection.name, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch collections: \(error.localizedDescription)")
            return []
        }
    }
    
    func addDocument(_ document: Document, to collection: Collection) {
        collection.addToDocuments(document)
        save()
    }
    
    func removeDocument(_ document: Document, from collection: Collection) {
        collection.removeFromDocuments(document)
        save()
    }
}
