import Foundation
import Compression

extension FileManager {
    
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        try unzipData(data, to: destinationURL)
    }
    
    private func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    
    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }
    
    private func unzipData(_ data: Data, to destinationURL: URL) throws {
        var index = 0
        
        while index < data.count - 4 {
            // Look for local file header signature (0x04034b50)
            let signature = readUInt32(data, at: index)
            
            if signature == 0x04034b50 {
                // Parse local file header
                guard index + 30 <= data.count else { break }
                
                let compressionMethod = readUInt16(data, at: index + 8)
                let compressedSize = Int(readUInt32(data, at: index + 18))
                let uncompressedSize = Int(readUInt32(data, at: index + 22))
                let fileNameLength = Int(readUInt16(data, at: index + 26))
                let extraFieldLength = Int(readUInt16(data, at: index + 28))
                
                let fileNameStart = index + 30
                let fileNameEnd = fileNameStart + fileNameLength
                
                guard fileNameEnd <= data.count else { break }
                
                let fileNameData = data[fileNameStart..<fileNameEnd]
                guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                    index += 1
                    continue
                }
                
                let dataStart = fileNameEnd + extraFieldLength
                let dataEnd = dataStart + compressedSize
                
                guard dataEnd <= data.count else { break }
                
                let fileURL = destinationURL.appendingPathComponent(fileName)
                
                // Create directory if needed
                if fileName.hasSuffix("/") {
                    try createDirectory(at: fileURL, withIntermediateDirectories: true)
                } else {
                    // Create parent directory
                    let parentDir = fileURL.deletingLastPathComponent()
                    if !fileExists(atPath: parentDir.path) {
                        try createDirectory(at: parentDir, withIntermediateDirectories: true)
                    }
                    
                    let compressedData = Data(data[dataStart..<dataEnd])
                    
                    if compressionMethod == 0 {
                        // Stored (no compression)
                        try compressedData.write(to: fileURL)
                    } else if compressionMethod == 8 {
                        // Deflate
                        if let decompressedData = decompress(compressedData, expectedSize: uncompressedSize) {
                            try decompressedData.write(to: fileURL)
                        }
                    }
                }
                
                index = dataEnd
            } else if signature == 0x02014b50 {
                // Central directory - we're done with file entries
                break
            } else {
                index += 1
            }
        }
    }
    
    private func decompress(_ data: Data, expectedSize: Int) -> Data? {
        guard !data.isEmpty, expectedSize > 0 else { return Data() }
        
        var decompressedData = Data(count: expectedSize)
        
        let result = decompressedData.withUnsafeMutableBytes { destBuffer in
            data.withUnsafeBytes { sourceBuffer in
                guard let destPtr = destBuffer.baseAddress,
                      let sourcePtr = sourceBuffer.baseAddress else {
                    return 0
                }
                
                return compression_decode_buffer(
                    destPtr.assumingMemoryBound(to: UInt8.self),
                    expectedSize,
                    sourcePtr.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        if result > 0 {
            decompressedData.count = result
            return decompressedData
        }
        
        return nil
    }
}
