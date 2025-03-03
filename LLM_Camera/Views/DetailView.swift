import SwiftUI
import SwiftData

struct DetailView: View {
    let photo: PhotoItem
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var photoLibraryManager: PhotoLibraryManager
    @State private var showDeleteAlert = false
    @State private var displayImage: UIImage?
    @State private var isImageLoading = true
    @State private var imageLoadError = false
    @State private var loadAttempts = 0
    
    // Initialize with externally provided image
    init(photo: PhotoItem, preloadedImage: UIImage? = nil) {
        self.photo = photo
        self._displayImage = State(initialValue: preloadedImage)
        self._isImageLoading = State(initialValue: preloadedImage == nil)
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Image display area
                        ZStack {
                            Color.black
                            
                            if isImageLoading {
                                VStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(2)
                                    
                                    if loadAttempts > 0 {
                                        Text("Loading image... (Attempt \(loadAttempts))")
                                            .foregroundColor(.white)
                                            .padding(.top, 16)
                                    }
                                }
                            } else if let uiImage = displayImage {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.width)
                                    .clipped()
                            } else if imageLoadError {
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                    
                                    Text("Failed to load image")
                                        .foregroundColor(.white)
                                        .padding(.top, 10)
                                    
                                    Button(action: {
                                        retryLoadImage()
                                    }) {
                                        Text("Retry")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                    .padding(.top, 16)
                                }
                            }
                        }
                        .frame(height: geometry.size.width)
                        
                        // Description display area
                        VStack(alignment: .leading, spacing: 16) {
                            // Capture time
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.gray)
                                Text(formattedDate(photo.timestamp))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.top, 16)
                            
                            // Prompt
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Input Prompt")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(photo.prompt)
                                    .font(.body)
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            // ChatGPT Response
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ChatGPT Response")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(photo.imageDescription)
                                    .font(.body)
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                }
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Gallery")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Share button
                        Button(action: {
                            sharePhoto()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(displayImage == nil)
                        
                        // Delete button
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Photo"),
                    message: Text("Are you sure you want to delete this photo?"),
                    primaryButton: .destructive(Text("Delete")) {
                        deletePhoto()
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            }
            .onAppear {
                // Only load image if not already loaded
                if displayImage == nil {
                    loadImageData()
                } else {
                    isImageLoading = false
                    print("DetailView - Using preloaded image: \(displayImage!.size.width) x \(displayImage!.size.height)")
                }
            }
        }
    }
    
    private func loadImageData() {
        isImageLoading = true
        imageLoadError = false
        loadAttempts += 1
        
        // Validate image data
        if photo.imageData.isEmpty {
            print("DetailView - Error: Image data is empty (ID: \(photo.id))")
            DispatchQueue.main.async {
                self.isImageLoading = false
                self.imageLoadError = true
            }
            return
        }
        
        // Check image data size
        print("DetailView - Image data size: \(photo.imageData.count) bytes (Attempt: \(loadAttempts), ID: \(photo.id))")
        
        // Check cached image first
        if let cachedImage = photo.image {
            print("DetailView - Using cached image: \(cachedImage.size.width) x \(cachedImage.size.height)")
            self.displayImage = cachedImage
            self.isImageLoading = false
            return
        }
        
        // Load image in background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Check image data header (for debugging)
            if photo.imageData.count > 4 {
                let header = photo.imageData.prefix(4).map { String(format: "%02X", $0) }.joined()
                print("DetailView - Image data header: \(header)")
            }
            
            // Try various methods to load the image
            var loadedImage: UIImage? = nil
            
            // 1. Default method
            loadedImage = UIImage(data: photo.imageData)
            
            // 2. Try alternative options if default method fails
            if loadedImage == nil && photo.imageData.count > 0 {
                // Create a copy of image data
                let dataCopy = Data(photo.imageData)
                loadedImage = UIImage(data: dataCopy)
                
                if loadedImage != nil {
                    print("DetailView - Successfully loaded image using data copy")
                }
            }
            
            if let image = loadedImage {
                print("DetailView - Successfully loaded image: \(image.size.width) x \(image.size.height) (Attempt: \(loadAttempts))")
                DispatchQueue.main.async {
                    self.displayImage = image
                    self.isImageLoading = false
                }
            } else {
                print("DetailView - Failed to load image: Invalid image data (Attempt: \(loadAttempts))")
                DispatchQueue.main.async {
                    self.isImageLoading = false
                    self.imageLoadError = true
                }
            }
        }
    }
    
    private func retryLoadImage() {
        loadImageData()
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func sharePhoto() {
        guard let image = displayImage else { 
            print("No image available to share")
            return 
        }
        
        let text = """
        📸 Capture Time: \(formattedDate(photo.timestamp))
        
        🤖 ChatGPT Description:
        \(photo.imageDescription)
        """
        
        let items: [Any] = [image, text]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func deletePhoto() {
        photoLibraryManager.deletePhoto(photo: photo)
        presentationMode.wrappedValue.dismiss()
    }
} 