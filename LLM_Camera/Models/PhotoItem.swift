import Foundation
import SwiftUI
import SwiftData

@Model
final class PhotoItem {
    var id: UUID
    var imageData: Data
    var imageDescription: String
    var prompt: String
    var timestamp: Date
    
    // Transient property for storing cached image
    @Transient private var cachedImage: UIImage?
    
    init(imageData: Data, imageDescription: String, prompt: String) {
        self.id = UUID()
        self.imageData = imageData
        self.imageDescription = imageDescription
        self.prompt = prompt
        self.timestamp = Date()
    }
    
    var image: UIImage? {
        // Return cached image if available
        if let cachedImage = cachedImage {
            return cachedImage
        }
        
        // Validate image data
        if imageData.isEmpty {
            print("PhotoItem: Image data is empty (ID: \(id))")
            return nil
        }
        
        // Check image data header (for debugging)
        if imageData.count > 4 {
            let header = imageData.prefix(4).map { String(format: "%02X", $0) }.joined()
            print("PhotoItem: Image data header: \(header) (ID: \(id))")
        }
        
        // Try various methods to load the image
        var loadedImage: UIImage? = nil
        
        // 1. Default method
        loadedImage = UIImage(data: imageData)
        
        // 2. Try alternative options if default method fails
        if loadedImage == nil && imageData.count > 0 {
            // Create a copy of image data
            let dataCopy = Data(imageData)
            loadedImage = UIImage(data: dataCopy)
            
            if loadedImage != nil {
                print("PhotoItem: Successfully loaded image using data copy (ID: \(id))")
            }
        }
        
        // Check image loading result
        if let image = loadedImage {
            print("PhotoItem: Successfully loaded image: \(image.size.width) x \(image.size.height) (ID: \(id))")
            // Store the created image in cache
            cachedImage = image
            return image
        } else {
            print("PhotoItem: Failed to create UIImage from image data (ID: \(id), data size: \(imageData.count) bytes)")
            return nil
        }
    }
} 