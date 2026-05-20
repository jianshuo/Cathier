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

    private static func repoURL(_ path: String) -> URL? {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/\(path)")
    }

    /// A GitHub API request with the four standard headers pre-set.
    private static func githubRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(bundleToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// Send `request`, require a 201, and pull a string value out of the JSON body.
    /// Supports a nested key path (e.g. ["content", "download_url"]).
    private static func send(_ request: URLRequest, expecting keyPath: [String]) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 201 {
            throw GitHubError.httpError(http.statusCode)
        }
        var node = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        for key in keyPath.dropLast() { node = node?[key] as? [String: Any] }
        guard let value = node?[keyPath.last ?? ""] as? String else { throw GitHubError.decodeFailed }
        return value
    }

    private static func postIssue(title: String, body: String, labels: [String]) async throws -> URL {
        guard let url = repoURL("issues") else { throw GitHubError.decodeFailed }
        var request = githubRequest(url: url, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["title": title, "body": body, "labels": labels])
        guard let issueURL = URL(string: try await send(request, expecting: ["html_url"])) else {
            throw GitHubError.decodeFailed
        }
        return issueURL
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
        guard let url = repoURL("contents/feedback-screenshots/\(filename)") else { throw GitHubError.decodeFailed }

        var request = githubRequest(url: url, method: "PUT")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "message": "feedback: add screenshot",
            "content": imageData.base64EncodedString()
        ])

        return try await send(request, expecting: ["content", "download_url"])
    }

    static func createFeedbackIssue(title: String, body: String, images: [UIImage] = [], submittedBy: String = "") async throws -> URL {
        var imageURLs: [String] = []
        for image in images {
            if let imageUrl = try? await uploadImage(image) {
                imageURLs.append(imageUrl)
            }
        }

        var fullBody = submittedBy.isEmpty ? body : "**From:** \(submittedBy)\n\n\(body)"
        if !imageURLs.isEmpty {
            let imageMarkdown = imageURLs.enumerated()
                .map { i, url in "![Screenshot \(i + 1)](\(url))" }
                .joined(separator: "\n")
            fullBody += "\n\n### Screenshots\n\n\(imageMarkdown)"
        }
        fullBody += "\n\n---\n*Submitted from Cathier app. @claude please implement this feature.*"

        return try await postIssue(title: title, body: fullBody, labels: ["user-feedback"])
    }

    /// Open an issue from an automated source (MetricKit / CrashReporter).
    /// Different label set than user feedback, and no "@claude please implement"
    /// footer — these reports are diagnostic noise, not feature requests.
    static func createCrashIssue(title: String, body: String) async throws -> URL {
        try await postIssue(title: title, body: body, labels: ["crash", "auto-reported"])
    }
}
