import SwiftUI
import SwiftData

@main
struct LLM_CameraApp: App {
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    
    init() {
        // Set default prompt on first app launch
        if UserDefaults.standard.string(forKey: AppConstants.UserDefaults.savedPromptKey) == nil {
            UserDefaults.standard.set(AppConstants.UserDefaults.defaultPrompt, 
                                    forKey: AppConstants.UserDefaults.savedPromptKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            CameraView()
                .environmentObject(photoLibraryManager)
        }
        .modelContainer(photoLibraryManager.container)
    }
}
