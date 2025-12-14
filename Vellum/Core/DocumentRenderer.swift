import SwiftUI
import PDFKit
import CoreText

struct EPUBChapter: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let fileName: String
    var startIndex: Int = 0  // Character index in full text where this chapter starts
}

class DocumentRenderer: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 0
    @Published var isLoading = false
    @Published var isPaginating = false
    @Published var error: String?
    @Published var pages: [String] = []
    
    // EPUB-specific
    @Published var chapters: [EPUBChapter] = []
    @Published var currentChapterIndex: Int = 0
    @Published var isEPUB: Bool = false
    
    // Track page start positions in fullText for chapter navigation
    private var pageStartIndices: [Int] = []
    
    private var pdfDocument: PDFDocument?
    private var fullText: String = ""
    private var paginationTask: DispatchWorkItem?
    
    var document: Document?
    
    var currentChapter: EPUBChapter? {
        guard isEPUB, currentChapterIndex < chapters.count else { return nil }
        return chapters[currentChapterIndex]
    }
    
    func load(document: Document) {
        self.document = document
        isLoading = true
        error = nil
        pages = []
        fullText = ""
        chapters = []
        currentChapterIndex = 0
        isEPUB = false
        
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
        case "epub":
            loadEPUB(from: url, savedPage: savedPage)
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
    
    private func loadEPUB(from url: URL, savedPage: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                var extractedChapters = try self.extractEPUBChapters(from: url)
                
                // Concatenate all chapters into full text, tracking start positions
                var combinedText = ""
                for i in 0..<extractedChapters.count {
                    extractedChapters[i].startIndex = combinedText.count
                    combinedText += extractedChapters[i].content
                    // Add chapter separator
                    if i < extractedChapters.count - 1 {
                        combinedText += "\n\n"
                    }
                }
                
                DispatchQueue.main.async {
                    if combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.error = "Could not extract text from EPUB."
                        self.isLoading = false
                        return
                    }
                    
                    self.isEPUB = true
                    self.chapters = extractedChapters
                    self.fullText = combinedText
                    self.totalPages = 1
                    self.pages = [self.fullText]
                    self.currentPage = savedPage
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to load EPUB: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func goToChapter(_ index: Int) {
        guard isEPUB, index >= 0, index < chapters.count else { return }
        currentChapterIndex = index
        
        // Find the page that contains the start of this chapter
        let chapterStart = chapters[index].startIndex
        
        // Use pageStartIndices if available (set during pagination)
        if !pageStartIndices.isEmpty {
            for (pageIndex, startIndex) in pageStartIndices.enumerated() {
                let endIndex = pageIndex + 1 < pageStartIndices.count ? pageStartIndices[pageIndex + 1] : fullText.count
                
                if chapterStart >= startIndex && chapterStart < endIndex {
                    currentPage = pageIndex
                    return
                }
            }
        }
        
        // Fallback: if chapter starts at the very end, go to last page
        if !pages.isEmpty {
            currentPage = pages.count - 1
        }
    }
    
    private func extractEPUBChapters(from url: URL) throws -> [EPUBChapter] {
        let fileManager = FileManager.default
        
        // Create temp directory for extraction
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Unzip EPUB
        try fileManager.unzipItem(at: url, to: tempDir)
        
        // Parse the spine/reading order from content.opf
        var chapters: [EPUBChapter] = []
        var spineItems: [(id: String, href: String)] = []
        var manifest: [String: String] = [:] // id -> href
        var tocItems: [(title: String, href: String)] = []
        var opfDir: URL = tempDir
        
        // Find container.xml to locate the OPF file
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
        var opfPath: String?
        
        if let containerData = try? String(contentsOf: containerPath, encoding: .utf8) {
            if let range = containerData.range(of: "full-path=\"([^\"]+)\"", options: .regularExpression) {
                let match = containerData[range]
                opfPath = String(match.dropFirst(11).dropLast(1))
            }
        }
        
        // Find and parse OPF file
        let opfURL: URL
        if let opfPath = opfPath {
            opfURL = tempDir.appendingPathComponent(opfPath)
            opfDir = opfURL.deletingLastPathComponent()
        } else {
            // Fallback: search for .opf file
            let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: nil)
            var foundOPF: URL?
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension.lowercased() == "opf" {
                    foundOPF = fileURL
                    break
                }
            }
            guard let found = foundOPF else {
                throw NSError(domain: "EPUB", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find OPF file"])
            }
            opfURL = found
            opfDir = opfURL.deletingLastPathComponent()
        }
        
        // Parse OPF for manifest and spine
        if let opfContent = try? String(contentsOf: opfURL, encoding: .utf8) {
            // Extract manifest items - simpler approach: find all id and href pairs in <item> tags
            let itemParts = opfContent.components(separatedBy: "<item")
            for part in itemParts.dropFirst() {
                // Find the end of this tag
                guard let tagEnd = part.firstIndex(of: ">") else { continue }
                let tagContent = String(part[..<tagEnd])
                
                // Extract id
                var itemId: String?
                if let idMatch = tagContent.range(of: "id=\"[^\"]+\"", options: .regularExpression) {
                    let idValue = tagContent[idMatch]
                    itemId = String(idValue.dropFirst(4).dropLast(1))
                } else if let idMatch = tagContent.range(of: "id='[^']+'", options: .regularExpression) {
                    let idValue = tagContent[idMatch]
                    itemId = String(idValue.dropFirst(4).dropLast(1))
                }
                
                // Extract href
                var itemHref: String?
                if let hrefMatch = tagContent.range(of: "href=\"[^\"]+\"", options: .regularExpression) {
                    let hrefValue = tagContent[hrefMatch]
                    itemHref = String(hrefValue.dropFirst(6).dropLast(1))
                } else if let hrefMatch = tagContent.range(of: "href='[^']+'", options: .regularExpression) {
                    let hrefValue = tagContent[hrefMatch]
                    itemHref = String(hrefValue.dropFirst(6).dropLast(1))
                }
                
                if let id = itemId, let href = itemHref {
                    manifest[id] = href.removingPercentEncoding ?? href
                }
            }
            
            // Extract spine items - simpler approach
            let spineParts = opfContent.components(separatedBy: "<itemref")
            for part in spineParts.dropFirst() {
                guard let tagEnd = part.firstIndex(of: ">") else { continue }
                let tagContent = String(part[..<tagEnd])
                
                var idref: String?
                if let idrefMatch = tagContent.range(of: "idref=\"[^\"]+\"", options: .regularExpression) {
                    let idrefValue = tagContent[idrefMatch]
                    idref = String(idrefValue.dropFirst(7).dropLast(1))
                } else if let idrefMatch = tagContent.range(of: "idref='[^']+'", options: .regularExpression) {
                    let idrefValue = tagContent[idrefMatch]
                    idref = String(idrefValue.dropFirst(7).dropLast(1))
                }
                
                if let idref = idref, let href = manifest[idref] {
                    spineItems.append((id: idref, href: href))
                }
            }
        }
        
        // Try to parse NCX or NAV for TOC titles
        tocItems = parseTOC(in: tempDir, opfDir: opfDir, manifest: manifest)
        
        // Build chapters from spine
        var chapterNumber = 1
        for spineItem in spineItems {
            // Try multiple path resolutions
            var fileURL = opfDir.appendingPathComponent(spineItem.href)
            var htmlContent: String?
            
            // Try direct path
            htmlContent = try? String(contentsOf: fileURL, encoding: .utf8)
            
            // Try URL decoded path
            if htmlContent == nil, let decoded = spineItem.href.removingPercentEncoding {
                fileURL = opfDir.appendingPathComponent(decoded)
                htmlContent = try? String(contentsOf: fileURL, encoding: .utf8)
            }
            
            // Try from temp directory root
            if htmlContent == nil {
                fileURL = tempDir.appendingPathComponent(spineItem.href)
                htmlContent = try? String(contentsOf: fileURL, encoding: .utf8)
            }
            
            if let htmlContent = htmlContent {
                let text = stripHTMLForEPUB(htmlContent)
                let fileName = spineItem.href.components(separatedBy: "/").last ?? spineItem.href
                
                // Find matching TOC title
                var title = tocItems.first(where: { 
                    $0.href.contains(fileName) || fileName.contains($0.href.components(separatedBy: "#").first ?? "")
                })?.title
                
                // Fallback: extract title from HTML
                if title == nil {
                    title = extractTitleFromHTML(htmlContent)
                }
                
                // Final fallback: use chapter number (only for non-empty content chapters)
                if title == nil && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = "Chapter \(chapterNumber)"
                    chapterNumber += 1
                }
                
                // Include even chapters with minimal content (like cover pages)
                chapters.append(EPUBChapter(
                    title: title ?? fileName,
                    content: text,
                    fileName: fileName
                ))
            }
        }
        
        // If spine parsing failed, fall back to finding HTML files
        if chapters.isEmpty {
            let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: nil)
            var htmlFiles: [URL] = []
            
            while let fileURL = enumerator?.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "html" || ext == "xhtml" || ext == "htm" {
                    htmlFiles.append(fileURL)
                }
            }
            
            htmlFiles.sort { $0.lastPathComponent < $1.lastPathComponent }
            
            for (index, htmlFile) in htmlFiles.enumerated() {
                if let htmlContent = try? String(contentsOf: htmlFile, encoding: .utf8) {
                    let text = stripHTMLForEPUB(htmlContent)
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let title = extractTitleFromHTML(htmlContent) ?? "Chapter \(index + 1)"
                        chapters.append(EPUBChapter(
                            title: title,
                            content: text,
                            fileName: htmlFile.lastPathComponent
                        ))
                    }
                }
            }
        }
        
        return chapters
    }
    
    private func parseTOC(in tempDir: URL, opfDir: URL, manifest: [String: String]) -> [(title: String, href: String)] {
        var tocItems: [(title: String, href: String)] = []
        
        // Try NCX file first
        for (_, href) in manifest {
            if href.hasSuffix(".ncx") {
                let ncxURL = opfDir.appendingPathComponent(href)
                if let ncxContent = try? String(contentsOf: ncxURL, encoding: .utf8) {
                    // Parse text elements and content src separately, then match them
                    // Find all <text>...</text> content
                    let textPattern = "<text>([^<]+)</text>"
                    let srcPattern = "<content[^>]*src=\"([^\"]+)\""
                    
                    // Split by navPoint to process each one
                    let navPointParts = ncxContent.components(separatedBy: "<navPoint")
                    
                    for part in navPointParts.dropFirst() {
                        var title: String?
                        var src: String?
                        
                        // Extract text
                        if let textRegex = try? NSRegularExpression(pattern: textPattern, options: .caseInsensitive),
                           let match = textRegex.firstMatch(in: part, range: NSRange(part.startIndex..., in: part)),
                           let range = Range(match.range(at: 1), in: part) {
                            title = String(part[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        
                        // Extract src
                        if let srcRegex = try? NSRegularExpression(pattern: srcPattern, options: .caseInsensitive),
                           let match = srcRegex.firstMatch(in: part, range: NSRange(part.startIndex..., in: part)),
                           let range = Range(match.range(at: 1), in: part) {
                            src = String(part[range])
                        }
                        
                        if let t = title, let s = src {
                            tocItems.append((title: t, href: s))
                        }
                    }
                    break
                }
            }
        }
        
        return tocItems
    }
    
    private func extractTitleFromHTML(_ html: String) -> String? {
        // Try to find <title> tag
        if let titleRegex = try? NSRegularExpression(pattern: "<title[^>]*>([^<]+)</title>", options: .caseInsensitive) {
            if let match = titleRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let title = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty && title.count < 100 {
                    return title
                }
            }
        }
        
        // Try h1, h2
        for tag in ["h1", "h2"] {
            if let regex = try? NSRegularExpression(pattern: "<\(tag)[^>]*>([^<]+)</\(tag)>", options: .caseInsensitive) {
                if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range(at: 1), in: html) {
                    let title = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty && title.count < 100 {
                        return title
                    }
                }
            }
        }
        
        return nil
    }
    
    private func stripHTMLForEPUB(_ html: String) -> String {
        var result = html
        
        // Remove script tags
        if let scriptRegex = try? NSRegularExpression(pattern: "<script[^>]*>[\\s\\S]*?</script>", options: .caseInsensitive) {
            result = scriptRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // Remove style tags
        if let styleRegex = try? NSRegularExpression(pattern: "<style[^>]*>[\\s\\S]*?</style>", options: .caseInsensitive) {
            result = styleRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // Mark paragraph breaks with placeholder
        let paragraphPlaceholder = "###PARA###"
        result = result.replacingOccurrences(of: "</p>", with: paragraphPlaceholder, options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<br>", with: " ", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<br/>", with: " ", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<br />", with: " ", options: .caseInsensitive)
        
        // Remove all remaining HTML tags
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            result = tagRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&mdash;", with: "\u{2014}")
        result = result.replacingOccurrences(of: "&ndash;", with: "\u{2013}")
        result = result.replacingOccurrences(of: "&hellip;", with: "\u{2026}")
        result = result.replacingOccurrences(of: "&ldquo;", with: "\u{201C}")
        result = result.replacingOccurrences(of: "&rdquo;", with: "\u{201D}")
        result = result.replacingOccurrences(of: "&lsquo;", with: "\u{2018}")
        result = result.replacingOccurrences(of: "&rsquo;", with: "\u{2019}")
        
        // Normalize whitespace - convert all whitespace (including newlines) to single spaces
        if let whitespaceRegex = try? NSRegularExpression(pattern: "\\s+", options: []) {
            result = whitespaceRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        }
        
        // Restore paragraph breaks
        result = result.replacingOccurrences(of: paragraphPlaceholder, with: "\n\n")
        
        // Clean up spaces around paragraph breaks
        result = result.replacingOccurrences(of: " \n", with: "\n")
        result = result.replacingOccurrences(of: "\n ", with: "\n")
        
        // Reduce excessive blank lines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
            var pageStarts: [Int] = []
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
                        pageStarts.append(Int(currentIndex))
                        let remainingRange = NSRange(location: Int(currentIndex), length: Int(totalLength - currentIndex))
                        let remainingText = (textToPaginate as NSString).substring(with: remainingRange)
                        paginatedPages.append(remainingText.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    break
                }
                
                // Track the start index for this page
                pageStarts.append(Int(frameRange.location))
                
                // Extract the text for this page
                let pageRange = NSRange(location: Int(frameRange.location), length: Int(frameRange.length))
                var pageText = (textToPaginate as NSString).substring(with: pageRange)
                pageText = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !pageText.isEmpty {
                    paginatedPages.append(pageText)
                } else {
                    // Remove the start index if page is empty
                    pageStarts.removeLast()
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
                self.pageStartIndices = pageStarts
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
