import SwiftUI

struct PromptSettingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var prompt: String
    @State private var editingPrompt: String
    @State private var apiKey: String
    @State private var showResetAlert = false
    @State private var showAPIKeyInfo = false
    
    private let defaultPrompt = AppConstants.UserDefaults.defaultPrompt
    
    init(prompt: Binding<String>) {
        self._prompt = prompt
        self._editingPrompt = State(initialValue: prompt.wrappedValue)
        self._apiKey = State(initialValue: UserDefaults.standard.string(forKey: AppConstants.UserDefaults.savedAPIKey) ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // API Key Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ChatGPT API Key")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            SecureField("Enter your API key", text: $apiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Button(action: {
                                showAPIKeyInfo = true
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if apiKey.isEmpty {
                            Text("Image analysis feature will not work without an API key")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.top)
                    
                    Divider()
                    
                    Text("Prompt Settings")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Set the prompt for image analysis. More specific prompts will yield more detailed analysis results.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // Prompt Examples Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Prompt Examples:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                promptExampleButton("Please describe this image in detail.")
                                promptExampleButton("List all objects visible in this photo.")
                                promptExampleButton("Describe the mood and emotions in this scene.")
                                promptExampleButton("What are the most notable features in this image?")
                            }
                        }
                    }
                    
                    // Text Editor
                    Text("Prompt:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $editingPrompt)
                        .font(.body)
                        .padding(10)
                        .frame(minHeight: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    HStack {
                        // Reset Button
                        Button(action: {
                            showResetAlert = true
                        }) {
                            Text("Reset to Default")
                                .font(.headline)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        
                        Spacer()
                        
                        // Save Button
                        Button(action: {
                            // Save API key
                            UserDefaults.standard.set(apiKey, forKey: AppConstants.UserDefaults.savedAPIKey)
                            // Save prompt
                            prompt = editingPrompt
                            UserDefaults.standard.synchronize()
                            
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Save")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 120)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.bottom)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Reset Prompt", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    editingPrompt = defaultPrompt
                }
            } message: {
                Text("Are you sure you want to reset the prompt to default?")
            }
            .alert("API Key Information", isPresented: $showAPIKeyInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You can obtain a ChatGPT API key from the OpenAI website. The API key is securely stored on your device and is only used for image analysis requests.")
            }
        }
    }
    
    private func promptExampleButton(_ example: String) -> some View {
        Button(action: {
            editingPrompt = example
        }) {
            Text(example)
                .font(.subheadline)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
} 