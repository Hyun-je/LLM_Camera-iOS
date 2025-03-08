import Foundation
import UIKit

class ChatGPTService {
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    private func getAPIKey() -> String? {
        return UserDefaults.standard.string(forKey: AppConstants.UserDefaults.savedAPIKey)
    }
    
    func analyzeImage(_ image: UIImage, withPrompt prompt: String) async throws -> String {
        // Check API key
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw NSError(domain: "ChatGPTService", code: 0, userInfo: [NSLocalizedDescriptionKey: "API key is not set"])
        }
        
        // Encode image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ChatGPTService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Create API request body
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 2000
        ]
        
        // Create URL request
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert request body to JSON
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Send API request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ChatGPTService", code: 2, userInfo: [NSLocalizedDescriptionKey: "API request failed: \(errorMessage)"])
        }
        
        // Parse response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        } else {
            throw NSError(domain: "ChatGPTService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse API response"])
        }
    }
    
    // Method using completion handler
    func analyzeImage(image: UIImage, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let result = try await analyzeImage(image, withPrompt: prompt)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
} 
