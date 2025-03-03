import UIKit
import CoreMotion

class OrientationDetector {
    private let motionManager = CMMotionManager()
    
    // Property to store current device orientation
    private(set) var currentOrientation: UIDeviceOrientation = .unknown
    
    // Optional callback when orientation changes
    var orientationDidChangeHandler: ((UIDeviceOrientation) -> Void)?
    
    // Create singleton instance (use as needed)
    static let shared = OrientationDetector()
    
    func startDetectingOrientation(updateInterval: TimeInterval = 0.2) {
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer is not available")
            return
        }
        
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data, error == nil else {
                print("Accelerometer data error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let newOrientation = self.deviceOrientationFromAccelerometer(data)
            
            // Update only if orientation changes and call callback
            if newOrientation != self.currentOrientation {
                self.currentOrientation = newOrientation
                self.orientationDidChangeHandler?(newOrientation)
            }
        }
    }
    
    func stopDetectingOrientation() {
        motionManager.stopAccelerometerUpdates()
    }
    
    private func deviceOrientationFromAccelerometer(_ data: CMAccelerometerData) -> UIDeviceOrientation {
        let x = data.acceleration.x
        let y = data.acceleration.y
        let z = data.acceleration.z
        
        // Determine orientation based on the axis with the largest absolute value
        let absX = abs(x)
        let absY = abs(y)
        let absZ = abs(z)
        
        if absZ > absX && absZ > absY {
            // Device is lying flat
            if z > 0 {
                return .faceDown
            } else {
                return .faceUp
            }
        } else if absY > absX {
            // Y axis acceleration is the largest (portrait orientation)
            if y > 0 {
                return .portraitUpsideDown
            } else {
                return .portrait
            }
        } else {
            // X axis acceleration is the largest (landscape orientation)
            if x > 0 {
                return .landscapeRight
            } else {
                return .landscapeLeft
            }
        }
    }
    
    // Convenient method to return current orientation immediately
    func getCurrentOrientation() -> UIDeviceOrientation {
        return currentOrientation
    }
}
