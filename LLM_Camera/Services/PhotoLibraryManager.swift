import Foundation
import SwiftUI
import SwiftData

@MainActor
class PhotoLibraryManager: ObservableObject {
    @Published var container: ModelContainer
    
    init() {
        do {
            let schema = Schema([PhotoItem.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [config])
            print("PhotoLibraryManager: Model container initialization successful")
        } catch {
            print("PhotoLibraryManager: Model container initialization failed: \(error.localizedDescription)")
            fatalError("PhotoLibraryManager initialization failed: \(error.localizedDescription)")
        }
    }
    
    func addPhoto(imageData: Data, imageDescription: String, prompt: String) {
        // Image data validation
        guard !imageData.isEmpty else {
            print("PhotoLibraryManager: Image data to save is empty")
            return
        }
        
        // Validate image data by creating UIImage
        guard let image = UIImage(data: imageData) else {
            print("PhotoLibraryManager: Image data to save is invalid")
            return
        }
        
        let newPhoto = PhotoItem(imageData: imageData, imageDescription: imageDescription, prompt: prompt)
        container.mainContext.insert(newPhoto)
        
        do {
            try container.mainContext.save()
            print("PhotoLibraryManager: Photo saved successfully (ID: \(newPhoto.id), Data size: \(imageData.count) bytes, Image size: \(image.size.width) x \(image.size.height))")
        } catch {
            print("PhotoLibraryManager: Failed to save photo: \(error.localizedDescription)")
        }
    }
    
    func addPhoto(image: UIImage, imageDescription: String) {
        // Compress image with highest quality (1.0)
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            print("PhotoLibraryManager: Failed to convert image data")
            return
        }
        
        // Image data validation
        guard !imageData.isEmpty else {
            print("PhotoLibraryManager: Generated image data is empty")
            return
        }
        
        // Validate image data by recreating UIImage
        guard UIImage(data: imageData) != nil else {
            print("PhotoLibraryManager: Generated image data is invalid")
            return
        }
        
        print("PhotoLibraryManager: Image data generation successful: \(imageData.count) bytes, Image size: \(image.size.width) x \(image.size.height)")
        
        // Check image data header (for debugging)
        if imageData.count > 4 {
            let header = imageData.prefix(4).map { String(format: "%02X", $0) }.joined()
            print("PhotoLibraryManager: Image data header: \(header)")
        }
        
        let prompt = UserDefaults.standard.string(forKey: "savedPrompt") ?? "Image Description"
        
        addPhoto(imageData: imageData, imageDescription: imageDescription, prompt: prompt)
    }
    
    func deletePhoto(photo: PhotoItem) {
        container.mainContext.delete(photo)
        
        do {
            try container.mainContext.save()
            print("PhotoLibraryManager: Photo deleted successfully (ID: \(photo.id))")
        } catch {
            print("PhotoLibraryManager: Failed to delete photo: \(error.localizedDescription)")
        }
    }
    
    func getPhotoCount() -> Int {
        do {
            let descriptor = FetchDescriptor<PhotoItem>()
            let count = try container.mainContext.fetchCount(descriptor)
            print("PhotoLibraryManager: Number of saved photos: \(count)")
            return count
        } catch {
            print("PhotoLibraryManager: Failed to get photo count: \(error.localizedDescription)")
            return 0
        }
    }
} 