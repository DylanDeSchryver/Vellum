import SwiftUI
import PDFKit
import CoreText

class DocumentRenderer: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 0
    @Published var isLoading = false
    @Published var isPaginating = false
    @Published var error: String?
    @Published var pages: [String] = []
    
    private var pdfDocument: PDFDocument?
    private var fullText: String = ""
    private var paginationTask: DispatchWorkItem?
    
    var document: Document?
    
    func load(document: Document) {
        self.document = document
        isLoading = true
        error = nil
        pages = []
        fullText = ""
        
        guard let filePath = document.filePath else {
            error = "Document file not found"
            isLoading = false
            return
        }
        
        let url = URL(fileURLWithPath: filePath)
        let fileType = document.fileType ?? "pdf"
        
        let savedPage = Int(document.currentPage)
        
        switch fileType.lowercased() {
        case "pdf":
            loadPDF(from: url, savedPage: savedPage)
        case "txt":
            loadText(from: url)
            currentPage = min(savedPage, max(0, totalPages - 1))
        case "rtf":
            loadRTF(from: url)
            currentPage = min(savedPage, max(0, totalPages - 1))
        default:
            error = "Unsupported file type"
            isLoading = false
        }
    }
    
    private func loadPDF(from url: URL, savedPage: Int) {
        guard let pdf = PDFDocument(url: url) else {
            error = "Failed to load PDF"
            isLoading = false
            return
        }
        
        pdfDocument = pdf
        
        // Extract text from all pages on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var extractedText = ""
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i), let pageText = page.string {
                    extractedText += pageText
                    // Add page break marker between PDF pages
                    if i < pdf.pageCount - 1 {
                        extractedText += "\n\n"
                    }
                }
            }
            
            // Clean up PDF text: convert single newlines to spaces, preserve paragraph breaks
            let cleanedText = self?.cleanPDFText(extractedText) ?? extractedText
            let trimmedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if trimmedText.isEmpty {
                    self.error = "Could not extract text from PDF. The PDF may be image-based or protected."
                    self.isLoading = false
                    return
                }
                
                self.fullText = trimmedText
                // Initial pagination will happen when view provides dimensions
                self.totalPages = 1
                self.pages = [self.fullText]
                self.currentPage = min(savedPage, max(0, self.totalPages - 1))
                self.isLoading = false
            }
        }
    }
    
    private func loadText(from url: URL) {
        do {
            fullText = try String(contentsOf: url, encoding: .utf8)
            totalPages = 1
            pages = [fullText]
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
                fullText = attributedString.string
                totalPages = 1
                pages = [fullText]
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
    
    // Clean PDF text by converting single newlines to spaces while preserving paragraph breaks
    private func cleanPDFText(_ text: String) -> String {
        // First, normalize line endings
        var result = text.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        
        // Normalize quotes to standard forms for consistent handling
        result = result.replacingOccurrences(of: "\u{201C}", with: "\"") // left double quote
        result = result.replacingOccurrences(of: "\u{201D}", with: "\"") // right double quote
        result = result.replacingOccurrences(of: "\u{2018}", with: "'")  // left single quote
        result = result.replacingOccurrences(of: "\u{2019}", with: "'")  // right single quote
        
        // Preserve scene breaks (often *** or * * * or ---)
        let sceneBreakPlaceholder = "###SCENEBREAK###"
        result = result.replacingOccurrences(of: "* * *", with: sceneBreakPlaceholder)
        result = result.replacingOccurrences(of: "***", with: sceneBreakPlaceholder)
        result = result.replacingOccurrences(of: "---", with: sceneBreakPlaceholder)
        
        // Preserve paragraph breaks (multiple newlines)
        let paragraphPlaceholder = "###PARAGRAPH###"
        
        // Handle 3+ newlines as paragraph breaks
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        result = result.replacingOccurrences(of: "\n\n", with: paragraphPlaceholder)
        
        // Replace remaining single newlines with spaces (mid-paragraph line wraps from PDF)
        result = result.replacingOccurrences(of: "\n", with: " ")
        
        // Restore paragraph breaks
        result = result.replacingOccurrences(of: paragraphPlaceholder, with: "\n\n")
        
        // Clean up multiple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Dialog formatting: Add line break before opening quote that follows closing quote
        // This separates different speakers' dialog
        // Pattern: end quote + space + open quote -> end quote + newline + open quote
        let newline = "\n"
        result = result.replacingOccurrences(of: "\" \"", with: "\"" + newline + "\"")
        result = result.replacingOccurrences(of: "!\" \"", with: "!\"" + newline + "\"")
        result = result.replacingOccurrences(of: "?\" \"", with: "?\"" + newline + "\"")
        
        // Also handle when dialog attribution comes between quotes
        // Pattern: ." He said. " -> keep as paragraph, but "said. "" needs break
        let dialogPattern = try? NSRegularExpression(
            pattern: #"([.!?])"\s+(\w+\s+\w+[^"]{0,50})\s+""#,
            options: []
        )
        if let regex = dialogPattern {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1\"" + newline + "$2" + newline + "\""
            )
        }
        
        // Restore scene breaks with proper spacing
        let doubleNewline = "\n\n"
        result = result.replacingOccurrences(of: sceneBreakPlaceholder, with: doubleNewline + "* * *" + doubleNewline)
        
        // Trim spaces at start of lines
        let lines = result.components(separatedBy: "\n")
        result = lines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        
        // Clean up excessive newlines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return result
    }
    
    // Paginate text based on available size and font settings using efficient CoreText
    func paginateText(
        availableSize: CGSize,
        font: UIFont,
        lineSpacing: CGFloat,
        margins: CGFloat
    ) {
        guard !fullText.isEmpty else { return }
        
        let textWidth = availableSize.width - (margins * 2)
        let textHeight = availableSize.height - 80 // Account for top/bottom padding
        
        guard textWidth > 0 && textHeight > 0 else { return }
        
        // Cancel any existing pagination task
        paginationTask?.cancel()
        
        let textToPaginate = fullText
        
        DispatchQueue.main.async { [weak self] in
            self?.isPaginating = true
        }
        
        // Create work item for cancellation support
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = lineSpacing
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
            
            let attributedString = NSAttributedString(string: textToPaginate, attributes: attributes)
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            
            var paginatedPages: [String] = []
            var currentIndex: CFIndex = 0
            let totalLength = CFIndex(attributedString.length)
            let pageRect = CGRect(x: 0, y: 0, width: textWidth, height: textHeight)
            let path = CGPath(rect: pageRect, transform: nil)
            
            while currentIndex < totalLength {
                // Check for cancellation
                if self.paginationTask?.isCancelled == true {
                    return
                }
                
                // Create a frame for this page
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRangeMake(currentIndex, 0),
                    path,
                    nil
                )
                
                // Get the visible range for this frame
                let frameRange = CTFrameGetVisibleStringRange(frame)
                
                if frameRange.length == 0 {
                    // Nothing fits, add remaining text and break
                    if currentIndex < totalLength {
                        let remainingRange = NSRange(location: Int(currentIndex), length: Int(totalLength - currentIndex))
                        let remainingText = (textToPaginate as NSString).substring(with: remainingRange)
                        paginatedPages.append(remainingText.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    break
                }
                
                // Extract the text for this page
                let pageRange = NSRange(location: Int(frameRange.location), length: Int(frameRange.length))
                var pageText = (textToPaginate as NSString).substring(with: pageRange)
                pageText = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !pageText.isEmpty {
                    paginatedPages.append(pageText)
                }
                
                // Move to next position
                currentIndex = frameRange.location + frameRange.length
            }
            
            // Check for cancellation before updating UI
            if self.paginationTask?.isCancelled == true {
                return
            }
            
            DispatchQueue.main.async {
                guard self.paginationTask?.isCancelled != true else { return }
                
                self.pages = paginatedPages
                self.totalPages = self.pages.count
                self.isPaginating = false
                
                // Ensure current page is valid
                if self.currentPage >= self.totalPages {
                    self.currentPage = max(0, self.totalPages - 1)
                }
            }
        }
        
        paginationTask = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    func getFullText() -> String {
        return fullText
    }
    
    func getCurrentPageText() -> String {
        guard currentPage >= 0 && currentPage < pages.count else {
            return fullText
        }
        return pages[currentPage]
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
