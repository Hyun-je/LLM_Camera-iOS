import SwiftUI
import SwiftData
import PhotosUI

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
    
    // New state variables for photo library integration
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var importedImage: UIImage?
    @State private var showPromptInput = false
    @State private var prompt: String = UserDefaults.standard.string(forKey: AppConstants.UserDefaults.savedPromptKey) ?? AppConstants.UserDefaults.defaultPrompt
    @State private var isProcessingImportedImage = false
    @State private var processingError: String?
    @State private var showProcessingError = false
    
    private let chatGPTService = ChatGPTService()
    
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
                
                // Processing imported image indicator
                if isProcessingImportedImage {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(2)
                            
                            Text("Processing image...")
                                .foregroundColor(.white)
                                .padding(.top, 16)
                        }
                        .padding(30)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(16)
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        // Camera button
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                                .tint(.white)
                        }
                        
                        // New album button
                        Button(action: {
                            showPhotoPicker = true
                        }) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 18))
                                .tint(.white)
                        }
                        .disabled(isProcessingImportedImage)
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
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, newItem in
                if let newItem = newItem {
                    loadTransferable(from: newItem)
                }
            }
            .sheet(isPresented: $showPromptInput) {
                if let image = importedImage {
                    PromptInputView(image: image, prompt: prompt, onSubmit: { promptText in
                        processImportedImage(image, prompt: promptText)
                    }, onCancel: {
                        importedImage = nil
                    })
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
            .alert("Processing Error", isPresented: $showProcessingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(processingError ?? "An unknown error occurred while processing the image.")
            }
        }
    }
    
    private func loadTransferable(from item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let unwrappedData = data, let image = UIImage(data: unwrappedData) {
                        self.importedImage = image
                        self.showPromptInput = true
                    } else {
                        self.processingError = "Failed to load the selected image."
                        self.showProcessingError = true
                    }
                case .failure(let error):
                    self.processingError = "Failed to load the selected image: \(error.localizedDescription)"
                    self.showProcessingError = true
                }
                self.photoPickerItem = nil
            }
        }
    }
    
    private func processImportedImage(_ image: UIImage, prompt: String) {
        isProcessingImportedImage = true
        
        Task {
            do {
                let description = try await chatGPTService.analyzeImage(image, withPrompt: prompt)
                
                // Save to photo library
                if let imageData = image.jpegData(compressionQuality: 1.0) {
                    let newPhoto = PhotoItem(imageData: imageData, imageDescription: description, prompt: prompt)
                    modelContext.insert(newPhoto)
                    try modelContext.save()
                }
                
                DispatchQueue.main.async {
                    self.isProcessingImportedImage = false
                    self.importedImage = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessingImportedImage = false
                    self.processingError = "Failed to process image: \(error.localizedDescription)"
                    self.showProcessingError = true
                    self.importedImage = nil
                }
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
