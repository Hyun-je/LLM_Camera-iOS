import SwiftUI
import SwiftData

struct GalleryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoItem.timestamp, order: .reverse) private var photos: [PhotoItem]
    
    @State private var selectedPhoto: PhotoItem?
    @State private var selectedImage: UIImage?
    @State private var showDetailView = false
    @State private var isLoadingImage = false
    @State private var isEditMode = false
    @State private var selectedPhotos = Set<PhotoItem>()
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if photos.isEmpty {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Photos")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(photos) { photo in
                                VStack(spacing: 0) {
                                    GalleryItemView(photo: photo, isSelected: selectedPhotos.contains(photo), isEditMode: isEditMode)
                                        .onTapGesture {
                                            if isEditMode {
                                                togglePhotoSelection(photo)
                                            } else {
                                                selectPhoto(photo)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    
                                    // Add divider
                                    if photo.id != photos.last?.id {
                                        Divider()
                                            .padding(.horizontal, 16)
                                            .padding(.top, 8)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    
                    // Loading indicator
                    if isLoadingImage {
                        ZStack {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                            
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(2)
                                
                                Text("Loading image...")
                                    .foregroundColor(.white)
                                    .padding(.top, 16)
                            }
                            .padding(30)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(16)
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                            .tint(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !photos.isEmpty {
                        HStack {
                            if isEditMode {
                                Button(action: {
                                    if !selectedPhotos.isEmpty {
                                        showDeleteAlert = true
                                    }
                                }) {
                                    Text("Delete")
                                        .foregroundColor(.red)
                                }
                                .disabled(selectedPhotos.isEmpty)
                            }
                            
                            Button(action: {
                                withAnimation {
                                    isEditMode.toggle()
                                    if !isEditMode {
                                        selectedPhotos.removeAll()
                                    }
                                }
                            }) {
                                Text(isEditMode ? "Done" : "Edit")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showDetailView) {
                if let photo = selectedPhoto {
                    DetailView(photo: photo, preloadedImage: selectedImage)
                }
            }
            .alert("Delete Photos", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSelectedPhotos()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedPhotos.count) photo\(selectedPhotos.count > 1 ? "s" : "")?")
            }
        }
    }
    
    private func togglePhotoSelection(_ photo: PhotoItem) {
        if selectedPhotos.contains(photo) {
            selectedPhotos.remove(photo)
        } else {
            selectedPhotos.insert(photo)
        }
    }
    
    private func deleteSelectedPhotos() {
        for photo in selectedPhotos {
            modelContext.delete(photo)
        }
        selectedPhotos.removeAll()
        isEditMode = false
    }
    
    private func selectPhoto(_ photo: PhotoItem) {
        // Show loading state
        isLoadingImage = true
        
        // Set selected photo
        self.selectedPhoto = photo
        
        // Check image data and log
        print("GalleryView - Selected photo ID: \(photo.id)")
        
        // Validate image data
        if photo.imageData.isEmpty {
            print("GalleryView - Error: Image data is empty")
            self.selectedImage = nil
            self.isLoadingImage = false
            self.showDetailView = true
            return
        }
        
        print("GalleryView - Selected photo data size: \(photo.imageData.count) bytes")
        
        // Check cached image first
        if let cachedImage = photo.image {
            print("GalleryView - Using cached image: \(cachedImage.size.width) x \(cachedImage.size.height)")
            self.selectedImage = cachedImage
            self.isLoadingImage = false
            self.showDetailView = true
            return
        }
        
        // Attempt to load image - only show DetailView after loading is complete
        print("GalleryView - Starting image load...")
        
        DispatchQueue.global(qos: .userInitiated).async {
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
                    print("GalleryView - Successfully loaded image using data copy")
                }
            }
            
            // Check image data header (for debugging)
            if photo.imageData.count > 4 {
                let header = photo.imageData.prefix(4).map { String(format: "%02X", $0) }.joined()
                print("GalleryView - Image data header: \(header)")
            }
            
            // Return to main thread for UI updates
            DispatchQueue.main.async {
                // Clear loading state
                self.isLoadingImage = false
                
                if let image = loadedImage {
                    print("GalleryView - Successfully loaded selected image: \(image.size.width) x \(image.size.height)")
                    self.selectedImage = image
                } else {
                    print("GalleryView - Failed to load selected image: data size \(photo.imageData.count) bytes")
                    self.selectedImage = nil
                }
                
                // Show DetailView regardless of image load success
                self.showDetailView = true
            }
        }
    }
}

struct GalleryItemView: View {
    let photo: PhotoItem
    let isSelected: Bool
    let isEditMode: Bool
    @State private var displayImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    if let uiImage = displayImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width * 2/3)
                            .clipped()
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                            )
                        
                        if isEditMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(isSelected ? .blue : .white)
                                .background(
                                    Circle()
                                        .fill(isSelected ? .white : .black.opacity(0.5))
                                        .frame(width: 24, height: 24)
                                )
                                .padding(8)
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: geometry.size.width, height: geometry.size.width * 2/3)
                            .cornerRadius(12)
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Description text
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(photo.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(photo.imageDescription)
                        .font(.subheadline)
                        .lineLimit(3)
                }
                .padding(.horizontal, 4)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .frame(height: UIScreen.main.bounds.width * 2/3 + 80) // Image height + text area height
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // Skip if image is already loaded
        if displayImage != nil {
            isLoading = false
            return
        }
        
        isLoading = true
        
        // Load image in background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Check image data size
            print("Gallery item image data size: \(photo.imageData.count) bytes")
            
            // Attempt to load image
            if let image = UIImage(data: photo.imageData) {
                print("Gallery item image load successful: \(image.size.width) x \(image.size.height)")
                DispatchQueue.main.async {
                    self.displayImage = image
                    self.isLoading = false
                }
            } else {
                print("Gallery item image load failed: Invalid image data")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
} 
