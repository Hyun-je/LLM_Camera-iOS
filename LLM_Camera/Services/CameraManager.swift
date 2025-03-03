import Foundation
import AVFoundation
import UIKit
import SwiftUI

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var isCameraReady = false
    @Published var recentImage: UIImage?
    @Published var isProcessing = false
    @Published var isUsingFrontCamera = false
    
    private let orientationDetector = OrientationDetector.shared
    
    // Completion handler for current capture
    private var photoCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        checkPermission()
        orientationDetector.startDetectingOrientation()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    func setupCamera() {
        do {
            // Stop session if already running
            if session.isRunning {
                session.stopRunning()
            }
            
            // Remove existing inputs and outputs
            for input in session.inputs {
                session.removeInput(input)
            }
            
            for output in session.outputs {
                session.removeOutput(output)
            }
            
            // Start session configuration
            session.beginConfiguration()
            
            // Set high-resolution photo capture
            session.sessionPreset = .photo
            
            // Set camera device - prefer back camera, try front camera if back is not available
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) 
                  ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                print("Camera not found")
                session.commitConfiguration()
                return
            }
            
            print("Camera device found: \(device.localizedName)")
            
            // Configure autofocus and exposure
            do {
                try device.lockForConfiguration()
                
                // Set autofocus
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                    print("Continuous autofocus mode set")
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                    print("Autofocus mode set")
                }
                
                // Set auto exposure
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                    print("Continuous auto exposure mode set")
                } else if device.isExposureModeSupported(AVCaptureDevice.ExposureMode.autoExpose) {
                    device.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
                    print("Auto exposure mode set")
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Failed to lock camera configuration: \(error.localizedDescription)")
            }
            
            // Set input
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                    print("Camera input successfully added")
                } else {
                    print("Cannot add camera input")
                    session.commitConfiguration()
                    return
                }
            } catch {
                print("Failed to create camera input: \(error.localizedDescription)")
                session.commitConfiguration()
                return
            }
            
            // Set output
            if session.canAddOutput(output) {
                session.addOutput(output)
                
                // Enable high-resolution photo capture
                output.isHighResolutionCaptureEnabled = true
                output.maxPhotoQualityPrioritization = .quality
                
                // Set available codec types
                if #available(iOS 13.0, *) {
                    if output.availablePhotoCodecTypes.contains(AVVideoCodecType.jpeg) {
                        output.photoSettingsForSceneMonitoring = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                    }
                }
                
                print("Camera output successfully added")
            } else {
                print("Cannot add camera output")
                session.commitConfiguration()
                return
            }
            
            // Complete session configuration
            session.commitConfiguration()
            
            DispatchQueue.main.async { [weak self] in
                self?.isCameraReady = true
                print("Camera setup complete: Camera is ready")
                
                // Start session in background after calling from main thread
                DispatchQueue.global(qos: .userInitiated).async {
                    if !(self?.session.isRunning ?? true) {
                        self?.session.startRunning()
                        print("Camera session auto-started")
                    }
                }
            }
        } catch {
            print("Camera setup error: \(error.localizedDescription)")
        }
    }
    
    func startSession() {
        guard !session.isRunning else { 
            print("Session is already running")
            return 
        }
        
        print("Starting camera session...")
        
        // Start session in background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Check if session is valid
            if self.session.inputs.isEmpty || self.session.outputs.isEmpty {
                print("No session inputs or outputs. Reconfiguring camera.")
                self.setupCamera()
            }
            
            self.session.startRunning()
            
            if self.session.isRunning {
                print("Camera session successfully started")
            } else {
                print("Failed to start camera session")
            }
        }
    }
    
    func stopSession() {
        guard session.isRunning else { 
            print("Session is already stopped")
            return 
        }
        
        print("Stopping camera session...")
        
        // Stop session in background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            print("Camera session stopped")
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        // Ignore if already processing
        guard !isProcessing else {
            print("Photo capture already in progress")
            completion(nil)
            return
        }
        
        isProcessing = true
        
        // Store completion handler
        self.photoCompletion = completion
        
        // Check if session is running
        guard session.isRunning else {
            print("Error: Camera session is not running")
            
            // Try to restart session
            print("Attempting to restart camera session")
            startSession()
            
            // Handle failure if session doesn't start
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(nil)
                self.photoCompletion = nil
            }
            return
        }
        
        // Check if output is connected
        guard session.outputs.contains(output) else {
            print("Error: Camera output is not connected to session")
            
            // Try to reconfigure camera
            print("Attempting to reconfigure camera")
            setupCamera()
            
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(nil)
                self.photoCompletion = nil
            }
            return
        }
        
        // Create photo settings
        let settings = AVCapturePhotoSettings()
        
        // Set high-quality photo settings
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        
        print("Capture initialized: Settings configured")
        
        // Set timeout timer
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let self = self, self.isProcessing else { return }
            
            print("Photo capture timeout")
            DispatchQueue.main.async {
                self.isProcessing = false
                self.photoCompletion?(nil)
                self.photoCompletion = nil
            }
        }
        
        print("Capture proceeding: Camera status checked, starting photo capture")

        // Pass self as delegate which implements AVCapturePhotoCaptureDelegate methods
        output.capturePhoto(with: settings, delegate: self)
        
        // Cancel timeout timer (when photoOutput method completes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !self.isProcessing {
                timeoutTimer.invalidate()
            }
        }
    }
    
    func toggleCamera() {
        // Ignore if already processing
        guard !isProcessing else {
            print("Camera is processing")
            return
        }
        
        isProcessing = true
        
        // Check current camera position
        let currentPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .back : .front
        
        // Start session reconfiguration
        session.beginConfiguration()
        
        // Remove existing input
        if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(currentInput)
        }
        
        // Find new camera device
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            print("Cannot find new camera")
            session.commitConfiguration()
            isProcessing = false
            return
        }
        
        do {
            // Create new input
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            
            // Add new input
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                isUsingFrontCamera = currentPosition == .front
                print("Camera switch successful: \(isUsingFrontCamera ? "front" : "back")")
            }
            
            // Set autofocus and exposure
            try newCamera.lockForConfiguration()
            if newCamera.isFocusModeSupported(.continuousAutoFocus) {
                newCamera.focusMode = .continuousAutoFocus
            }
            if newCamera.isExposureModeSupported(.continuousAutoExposure) {
                newCamera.exposureMode = .continuousAutoExposure
            }
            newCamera.unlockForConfiguration()
            
        } catch {
            print("Failed to switch camera: \(error.localizedDescription)")
        }
        
        // Complete session reconfiguration
        session.commitConfiguration()
        isProcessing = false
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate methods
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("photoOutput method called")
        
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isProcessing = false
                self.photoCompletion?(nil)
                self.photoCompletion = nil
            }
            return
        }
        
        let orientation = orientationDetector.currentOrientation
        print("Current detected orientation: \(orientation)")
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to convert image data")
            DispatchQueue.main.async {
                self.isProcessing = false
                self.photoCompletion?(nil)
                self.photoCompletion = nil
            }
            return
        }
        
        // Correct image orientation
        let correctedImage: UIImage
        switch orientation {
        case .portrait:
            correctedImage = image.rotate(radians: 0) // No rotation
        case .portraitUpsideDown:
            correctedImage = image.rotate(radians: .pi) // 180 degree rotation
        case .landscapeLeft:
            // Reverse rotation direction for front camera
            if isUsingFrontCamera {
                correctedImage = image.rotate(radians: .pi / 2) // 90 degree rotation
                print("Front camera landscapeLeft: 90 degree rotation")
            } else {
                correctedImage = image.rotate(radians: -.pi / 2) // -90 degree rotation
                print("Back camera landscapeLeft: -90 degree rotation")
            }
        case .landscapeRight:
            // Reverse rotation direction for front camera
            if isUsingFrontCamera {
                correctedImage = image.rotate(radians: -.pi / 2) // -90 degree rotation
                print("Front camera landscapeRight: -90 degree rotation")
            } else {
                correctedImage = image.rotate(radians: .pi / 2) // 90 degree rotation
                print("Back camera landscapeRight: 90 degree rotation")
            }
        default:
            correctedImage = image // Default no rotation
            print("Default orientation: No rotation")
        }
        
        print("Image orientation correction complete: \(correctedImage.size.width) x \(correctedImage.size.height)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recentImage = correctedImage
            self.isProcessing = false
            self.photoCompletion?(correctedImage)
            self.photoCompletion = nil
        }
    }
}

// Extension for UIImage rotation
extension UIImage {
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0)
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2.0, y: -size.height / 2.0, width: size.width, height: size.height))
            
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return rotatedImage ?? self
        }
        return self
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        DispatchQueue.main.async {
            // Setup preview layer
            cameraManager.preview = AVCaptureVideoPreviewLayer(session: cameraManager.session)
            cameraManager.preview?.frame = view.frame
            cameraManager.preview?.videoGravity = .resizeAspectFill
            cameraManager.preview?.connection?.videoOrientation = .portrait
            
            // Add preview layer
            view.layer.addSublayer(cameraManager.preview!)
            
            print("Camera preview view created")
            
            // Start session if not running
            if !cameraManager.session.isRunning {
                // Change priority to userInitiated for session start
                DispatchQueue.global(qos: .userInitiated).async {
                    cameraManager.startSession()
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            // Update preview layer frame
            if let previewLayer = cameraManager.preview {
                previewLayer.frame = uiView.bounds
                
                // Set orientation
                if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            // Start session if not running
            if !cameraManager.session.isRunning && cameraManager.isCameraReady {
                DispatchQueue.global(qos: .userInitiated).async {
                    cameraManager.startSession()
                }
            }
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        print("Camera preview view dismantled")
    }
} 
