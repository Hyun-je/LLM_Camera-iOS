# LLM Camera iOS App

An iOS application that captures images with the camera, analyzes them using ChatGPT, and displays the AI-generated descriptions.

## Features

- **Camera View**: 
  - Beautiful camera interface with front/back camera switching
  - Real-time device orientation detection
  - High-quality photo capture with automatic orientation correction
  - Live preview with portrait/landscape support
  
- **Gallery View**: 
  - Browse through captured photos with AI descriptions
  - Multi-select and batch delete functionality
  - Grid layout with smooth scrolling
  
- **Detail View**: 
  - View detailed information about each photo
  - Display original prompt and AI-generated response
  - High-resolution image display
  
- **Image Analysis**:
  - Real-time image analysis using ChatGPT API
  - Customizable prompts for different analysis styles
  - Error handling with user-friendly messages
  
- **Data Management**:
  - Persistent storage using SwiftData
  - Efficient image compression and storage
  - Automatic data validation and error handling

## Technical Details

### Core Components

- **OrientationDetector**: 
  - Real-time device orientation detection using accelerometer
  - Automatic image rotation correction
  - Support for all device orientations
  
- **CameraManager**: 
  - Advanced camera control and configuration
  - High-quality photo capture
  - Front/back camera support with proper orientation handling
  
- **PhotoLibraryManager**: 
  - SwiftData integration for persistent storage
  - Efficient image data management
  - Robust error handling and data validation

## Requirements

- iOS 17.0+ (required for SwiftData)
- Xcode 15.0+
- Swift 5.9+
- OpenAI API Key

## Setup

1. Clone the repository
2. Open the project in Xcode
3. Replace `"YOUR_OPENAI_API_KEY"` in `ChatGPTService.swift` with your actual OpenAI API key
4. Build and run the app on your device or simulator

## Usage

1. Launch the app to open the Camera View
2. Tap the document icon to customize the analysis prompt
3. Use the camera switch button to toggle between front/back cameras
4. Tap the capture button (AI icon) to take a photo
5. Wait for ChatGPT to analyze the image
6. Browse your photos in the Gallery View
7. Use multi-select mode to manage multiple photos
8. Tap on a photo to see detailed information
9. Use the share button to share photos and descriptions

## Architecture

The app follows a clean architecture approach with:

- **Models**: 
  - SwiftData models for photos and descriptions
  - Efficient data structures for image handling
  
- **Views**: 
  - SwiftUI views with modern iOS design patterns
  - Responsive layout supporting all orientations
  
- **Services**: 
  - Camera service with advanced configuration
  - ChatGPT integration for image analysis
  - Orientation detection service
  
- **Managers**: 
  - Photo library management with SwiftData
  - Efficient data handling and storage

## Data Storage

- SwiftData for persistent storage
- Efficient image compression
- Automatic data validation
- Error handling and recovery
- Local-only storage for privacy

## Privacy & Security

- All photos stored locally using SwiftData
- Secure API key handling
- Images sent to OpenAI are not stored on their servers
- No user data collection or third-party sharing
- Error messages designed for privacy

## License

This project is available under the MIT license. See the LICENSE file for more info. 