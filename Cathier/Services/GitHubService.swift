import Foundation
import UIKit

struct GitHubService {
    static let repoOwner = "jianshuo"
    static let repoName = "Cathier"

    enum GitHubError: LocalizedError {
        case httpError(Int)
        case decodeFailed

        var errorDescription: String? {
            switch self {
            case .httpError(let code): return "GitHub API request failed (HTTP \(code))."
            case .decodeFailed: return "Failed to parse GitHub response."
            }
        }
    }

    private static var bundleToken: String {
        Bundle.main.infoDictionary?["GitHubFeedbackPAT"] as? String ?? ""
    }

    private static func compressedImageData(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1500
        var processed = image
        if max(image.size.width, image.size.height) > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            processed = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        }
        return processed.jpegData(compressionQuality: 0.7)
    }

    private static func uploadImage(_ image: UIImage) async throws -> String {
        guard let imageData = compressedImageData(image) else { throw GitHubError.decodeFailed }

        let filename = "\(UUID().uuidString.lowercased()).jpg"
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/feedback-screenshots/\(filename)"
        guard let url = URL(string: urlString) else { throw GitHubError.decodeFailed }

        let payload: [String: Any] = [
            "message": "feedback: add screenshot",
            "content": imageData.base64EncodedString()
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(bundleToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (responseData, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            throw GitHubError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let content = json["content"] as? [String: Any],
              let downloadUrl = content["download_url"] as? String else {
            throw GitHubError.decodeFailed
        }

        return downloadUrl
    }

    static func createFeedbackIssue(title: String, body: String, images: [UIImage] = []) async throws -> URL {
        let resolvedToken = bundleToken

        var imageURLs: [String] = []
        for image in images {
            if let imageUrl = try? await uploadImage(image) {
                imageURLs.append(imageUrl)
            }
        }

        var fullBody = body
        if !imageURLs.isEmpty {
            let imageMarkdown = imageURLs.enumerated()
                .map { i, url in "![Screenshot \(i + 1)](\(url))" }
                .joined(separator: "\n")
            fullBody += "\n\n### Screenshots\n\n\(imageMarkdown)"
        }
        fullBody += "\n\n---\n*Submitted from Cathier app. @claude please implement this feature.*"

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/issues"
        guard let url = URL(string: urlString) else { throw GitHubError.decodeFailed }

        let payload: [String: Any] = [
            "title": title,
            "body": fullBody,
            "labels": ["user-feedback"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(resolvedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            throw GitHubError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let htmlUrl = json["html_url"] as? String,
              let issueURL = URL(string: htmlUrl) else {
            throw GitHubError.decodeFailed
        }

        return issueURL
    }
}
