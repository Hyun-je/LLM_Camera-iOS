import SwiftUI
import AVFoundation
import SwiftData
import AudioToolbox

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @EnvironmentObject private var photoLibraryManager: PhotoLibraryManager
    @Query(sort: \PhotoItem.timestamp, order: .reverse) private var photos: [PhotoItem]
    
    @State private var showGallery = false
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0
    @State private var processingTimer: Timer?
    @State private var showPromptSettings = false
    @State private var isCapturing = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var prompt: String = UserDefaults.standard.string(forKey: AppConstants.UserDefaults.savedPromptKey) 
        ?? AppConstants.UserDefaults.defaultPrompt {
        didSet {
            UserDefaults.standard.set(prompt, forKey: AppConstants.UserDefaults.savedPromptKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private let chatGPTService = ChatGPTService()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init() {
        // Remove prompt initialization code from init method
    }
    
    var body: some View {
        ZStack {
            // Camera preview
            if cameraManager.isCameraReady {
                CameraPreview(cameraManager: cameraManager)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
                Text("Camera access permission required")
                    .foregroundColor(.white)
            }
            
            // Top buttons
            VStack {
                HStack {
                    Spacer()
                    
                    // Prompt settings button
                    Button(action: {
                        showPromptSettings = true
                    }) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.top, 5)
                    .padding(.trailing, 20)
                    .disabled(isProcessing)
                }
                
                Spacer()
                
                // Capture button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isCapturing = true
                    }
                    
                    // Start capture after slight delay
                    captureAndAnalyze()
                    
                    // Restore button animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isCapturing = false
                    }
                
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: isCapturing ? 60 : 70, height: isCapturing ? 60 : 70)
                        
                        Circle()
                            .stroke(Color.yellow, lineWidth: 2)
                            .frame(width: isCapturing ? 70 : 80, height: isCapturing ? 70 : 80)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: isCapturing ? 25 : 30))
                            .tint(.yellow)
                    }
                }
                .disabled(isProcessing)
                .padding(.bottom, 30)
                .scaleEffect(isCapturing ? 0.9 : 1.0)
            }
            
            // Gallery button (bottom right)
            VStack {
                Spacer()
                HStack {
                    // Camera toggle button (left)
                    Button(action: {
                        cameraManager.toggleCamera()
                        impactFeedback.impactOccurred(intensity: 0.5)
                    }) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 30)
                    .padding(.leading, 20)
                    .disabled(isProcessing)
                    
                    Spacer()
                    
                    // Gallery button (right)
                    if !photos.isEmpty {
                        Button(action: {
                            showGallery = true
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 20))
                                Text("\(photos.count)")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                        .padding(.bottom, 30)
                        .padding(.trailing, 20)
                        .disabled(isProcessing)
                    }
                }
            }
            
            // Processing overlay
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                        
                        Text("Analyzing image...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ProgressView(value: processingProgress, total: 1.0)
                            .frame(width: 200)
                            .tint(.blue)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isProcessing)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showGallery) {
            GalleryView()
        }
        .sheet(isPresented: $showPromptSettings) {
            PromptSettingView(prompt: $prompt)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            print("CameraView appeared")
            // Check camera permission and start session
            if !cameraManager.isCameraReady {
                cameraManager.checkPermission()
            }
            
            // Start session if not running
            if !cameraManager.session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    cameraManager.startSession()
                }
            }
            
            // Check session status and try restart after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !cameraManager.session.isRunning && cameraManager.isCameraReady {
                    print("Session not started. Attempting restart...")
                    DispatchQueue.global(qos: .userInitiated).async {
                        cameraManager.setupCamera()
                        cameraManager.startSession()
                    }
                }
            }
        }
        .onDisappear {
            print("CameraView disappeared")
            // Stop session
            cameraManager.stopSession()
        }
    }
    
    private func captureAndAnalyze() {
        // Ignore if already processing
        guard !isProcessing else {
            print("Already processing an image")
            return
        }
        
        // Prepare haptic feedback
        impactFeedback.prepare()
        
        // Check if camera is ready
        guard cameraManager.isCameraReady else {
            showError("Camera is not ready. Please restart the app.")
            return
        }
        
        print("Starting photo capture")
        
        // Request photo capture
        cameraManager.capturePhoto { image in
            print("Photo capture completed: \(image != nil ? "success" : "failure")")
            
            guard let capturedImage = image else {
                self.showError("Failed to capture photo. Please try again.")
                return
            }
            
            print("Image size: \(capturedImage.size.width) x \(capturedImage.size.height)")
            
            // Start processing state
            DispatchQueue.main.async {
                withAnimation {
                    self.isProcessing = true
                }
                self.processingProgress = 0.0
                
                // Timer for visual progress indication
                self.processingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                    if self.processingProgress < 0.95 {
                        self.processingProgress += 0.01
                    }
                }
                
                print("Starting image analysis")
                
                // Request image analysis
                self.chatGPTService.analyzeImage(image: capturedImage, prompt: self.prompt) { result in
                    // Stop timer
                    self.processingTimer?.invalidate()
                    self.processingTimer = nil
                    
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let imageDescription):
                            print("Image analysis successful")
                            // Save image and description on success
                            self.processingProgress = 1.0
                            
                            // Success haptic feedback
                            let successFeedback = UINotificationFeedbackGenerator()
                            successFeedback.notificationOccurred(.success)
                            
                            // Save image
                            self.photoLibraryManager.addPhoto(image: capturedImage, imageDescription: imageDescription)
                            print("Image saved successfully")
                            
                            // Reset processing state
                            withAnimation {
                                self.isProcessing = false
                            }
                            
                        case .failure(let error):
                            print("Image analysis failed: \(error.localizedDescription)")
                            self.processingProgress = 1.0
                            
                            // Generate error code
                            let errorCode = String(error.localizedDescription.hash % 10000)
                            // Save image with error description
                            self.photoLibraryManager.addPhoto(image: capturedImage, imageDescription: "ChatGPT API Request Failed (Error \(errorCode))")
                            print("Image saved (analysis failed)")
                            
                            // Error haptic feedback
                            let errorFeedback = UINotificationFeedbackGenerator()
                            errorFeedback.notificationOccurred(.error)
                            
                            // Show error message
                            self.showError("ChatGPT API Request Failed (Error \(errorCode))")
                            
                            withAnimation {
                                self.isProcessing = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        print("Error: \(message)")
    }
} 
