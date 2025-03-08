import SwiftUI


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
