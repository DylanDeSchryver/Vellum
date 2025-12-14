import SwiftUI
import PDFKit

class DocumentRenderer: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 0
    @Published var isLoading = false
    @Published var error: String?
    
    private var pdfDocument: PDFDocument?
    private var textContent: String?
    
    var document: Document?
    
    func load(document: Document) {
        self.document = document
        isLoading = true
        error = nil
        
        guard let filePath = document.filePath else {
            error = "Document file not found"
            isLoading = false
            return
        }
        
        let url = URL(fileURLWithPath: filePath)
        let fileType = document.fileType ?? "pdf"
        
        switch fileType.lowercased() {
        case "pdf":
            loadPDF(from: url)
        case "txt":
            loadText(from: url)
        case "rtf":
            loadRTF(from: url)
        default:
            error = "Unsupported file type"
            isLoading = false
        }
        
        currentPage = Int(document.currentPage)
    }
    
    private func loadPDF(from url: URL) {
        if let pdf = PDFDocument(url: url) {
            pdfDocument = pdf
            totalPages = pdf.pageCount
            isLoading = false
        } else {
            error = "Failed to load PDF"
            isLoading = false
        }
    }
    
    private func loadText(from url: URL) {
        do {
            textContent = try String(contentsOf: url, encoding: .utf8)
            totalPages = 1
            isLoading = false
        } catch {
            self.error = "Failed to load text file: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func loadRTF(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                textContent = attributedString.string
                totalPages = 1
                isLoading = false
            } else {
                error = "Failed to parse RTF"
                isLoading = false
            }
        } catch {
            self.error = "Failed to load RTF file: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func getPDFDocument() -> PDFDocument? {
        return pdfDocument
    }
    
    func getTextContent() -> String? {
        return textContent
    }
    
    func goToPage(_ page: Int) {
        guard page >= 0 && page < totalPages else { return }
        currentPage = page
        
        if let doc = document {
            let progress = totalPages > 0 ? Double(page + 1) / Double(totalPages) : 0
            LibraryController.shared.updateProgress(for: doc, page: Int32(page), progress: progress)
        }
    }
    
    func nextPage() {
        goToPage(currentPage + 1)
    }
    
    func previousPage() {
        goToPage(currentPage - 1)
    }
    
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage + 1) / Double(totalPages)
    }
}
