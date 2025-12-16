import Foundation

struct EPUBMetadata {
    var title: String?
    var author: String?
    var description: String?
    var subjects: [String]
    var coverImageData: Data?
}

class EPUBMetadataExtractor {
    
    static func extractMetadata(from epubURL: URL) -> EPUBMetadata {
        let fileManager = FileManager.default
        var metadata = EPUBMetadata(subjects: [])
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: epubURL, to: tempDir)
            
            guard let opfURL = findOPFFile(in: tempDir) else {
                return metadata
            }
            
            let opfDir = opfURL.deletingLastPathComponent()
            
            guard let opfContent = try? String(contentsOf: opfURL, encoding: .utf8) else {
                return metadata
            }
            
            metadata.title = extractDCElement("title", from: opfContent)
            metadata.author = extractDCElement("creator", from: opfContent)
            metadata.description = extractDCElement("description", from: opfContent)
            metadata.subjects = extractAllDCElements("subject", from: opfContent)
            
            if let coverHref = findCoverImageHref(in: opfContent) {
                let coverURL = opfDir.appendingPathComponent(coverHref)
                metadata.coverImageData = try? Data(contentsOf: coverURL)
                
                if metadata.coverImageData == nil {
                    let decodedHref = coverHref.removingPercentEncoding ?? coverHref
                    let altCoverURL = opfDir.appendingPathComponent(decodedHref)
                    metadata.coverImageData = try? Data(contentsOf: altCoverURL)
                }
                
                if metadata.coverImageData == nil {
                    metadata.coverImageData = try? Data(contentsOf: tempDir.appendingPathComponent(coverHref))
                }
            }
            
        } catch {
            print("EPUB metadata extraction error: \(error)")
        }
        
        return metadata
    }
    
    private static func findOPFFile(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        
        let containerPath = directory.appendingPathComponent("META-INF/container.xml")
        if let containerData = try? String(contentsOf: containerPath, encoding: .utf8),
           let range = containerData.range(of: "full-path=\"([^\"]+)\"", options: .regularExpression) {
            let match = containerData[range]
            let opfPath = String(match.dropFirst(11).dropLast(1))
            return directory.appendingPathComponent(opfPath)
        }
        
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "opf" {
                return fileURL
            }
        }
        
        return nil
    }
    
    private static func extractDCElement(_ element: String, from opfContent: String) -> String? {
        let patterns = [
            "<dc:\(element)[^>]*>([^<]+)</dc:\(element)>",
            "<dc:\(element)[^>]*><!\\[CDATA\\[([^\\]]+)\\]\\]></dc:\(element)>",
            "<\(element)[^>]*>([^<]+)</\(element)>"
        ]
        
        for pattern in patterns {
            if let range = opfContent.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let match = String(opfContent[range])
                
                if let contentStart = match.firstIndex(of: ">"),
                   let contentEnd = match.lastIndex(of: "<") {
                    let startIndex = match.index(after: contentStart)
                    if startIndex < contentEnd {
                        var content = String(match[startIndex..<contentEnd])
                        
                        content = content
                            .replacingOccurrences(of: "<![CDATA[", with: "")
                            .replacingOccurrences(of: "]]>", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        content = decodeHTMLEntities(content)
                        
                        if !content.isEmpty {
                            return content
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func extractAllDCElements(_ element: String, from opfContent: String) -> [String] {
        var results: [String] = []
        
        let patterns = [
            "<dc:\(element)[^>]*>([^<]+)</dc:\(element)>",
            "<\(element)[^>]*>([^<]+)</\(element)>"
        ]
        
        for pattern in patterns {
            var searchRange = opfContent.startIndex..<opfContent.endIndex
            
            while let range = opfContent.range(of: pattern, options: [.regularExpression, .caseInsensitive], range: searchRange) {
                let match = String(opfContent[range])
                
                if let contentStart = match.firstIndex(of: ">"),
                   let contentEnd = match.lastIndex(of: "<") {
                    let startIndex = match.index(after: contentStart)
                    if startIndex < contentEnd {
                        var content = String(match[startIndex..<contentEnd])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        content = decodeHTMLEntities(content)
                        
                        if !content.isEmpty && !results.contains(content) {
                            results.append(content)
                        }
                    }
                }
                
                searchRange = range.upperBound..<opfContent.endIndex
            }
        }
        
        return results
    }
    
    private static func findCoverImageHref(in opfContent: String) -> String? {
        let coverMetaPatterns = [
            "<meta[^>]*name=\"cover\"[^>]*content=\"([^\"]+)\"",
            "<meta[^>]*content=\"([^\"]+)\"[^>]*name=\"cover\""
        ]
        
        var coverID: String?
        for pattern in coverMetaPatterns {
            if let range = opfContent.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let match = String(opfContent[range])
                if let idRange = match.range(of: "content=\"([^\"]+)\"", options: .regularExpression) {
                    let idMatch = String(match[idRange])
                    coverID = String(idMatch.dropFirst(9).dropLast(1))
                    break
                }
            }
        }
        
        if let coverID = coverID {
            let itemPattern = "<item[^>]*id=\"\(coverID)\"[^>]*href=\"([^\"]+)\""
            let altPattern = "<item[^>]*href=\"([^\"]+)\"[^>]*id=\"\(coverID)\""
            
            for pattern in [itemPattern, altPattern] {
                if let range = opfContent.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    let match = String(opfContent[range])
                    if let hrefRange = match.range(of: "href=\"([^\"]+)\"", options: .regularExpression) {
                        let hrefMatch = String(match[hrefRange])
                        return String(hrefMatch.dropFirst(6).dropLast(1))
                    }
                }
            }
        }
        
        let coverItemPatterns = [
            "<item[^>]*properties=\"cover-image\"[^>]*href=\"([^\"]+)\"",
            "<item[^>]*href=\"([^\"]+)\"[^>]*properties=\"cover-image\"",
            "<item[^>]*id=\"[^\"]*cover[^\"]*\"[^>]*href=\"([^\"]+)\"[^>]*media-type=\"image"
        ]
        
        for pattern in coverItemPatterns {
            if let range = opfContent.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let match = String(opfContent[range])
                if let hrefRange = match.range(of: "href=\"([^\"]+)\"", options: .regularExpression) {
                    let hrefMatch = String(match[hrefRange])
                    return String(hrefMatch.dropFirst(6).dropLast(1))
                }
            }
        }
        
        return nil
    }
    
    private static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " "),
            ("&#x27;", "'"),
            ("&#x2F;", "/"),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&hellip;", "…"),
            ("&rsquo;", "'"),
            ("&lsquo;", "'"),
            ("&rdquo;", "\u{201D}"),
            ("&ldquo;", "\u{201C}")
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        return result
    }
}
