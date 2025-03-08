import SwiftUI

// View for prompt input
struct PromptInputView: View {
    let image: UIImage
    @State private var promptText: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    init(image: UIImage, prompt: String, onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self._promptText = State(initialValue: prompt)
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 300)
                    .cornerRadius(12)
                    .padding()
                
                // Prompt input
                VStack(alignment: .leading) {
                    Text("Enter prompt for image analysis:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextEditor(text: $promptText)
                        .padding(8)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Image Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Process") {
                        onSubmit(promptText)
                    }
                    .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
} 