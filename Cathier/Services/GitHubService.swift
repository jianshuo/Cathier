import Foundation

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

    static func createFeedbackIssue(title: String, body: String) async throws -> URL {
        let resolvedToken = bundleToken

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/issues"
        guard let url = URL(string: urlString) else { throw GitHubError.decodeFailed }

        let fullBody = """
        \(body)

        ---
        *Submitted from Cathier app. @claude please implement this feature.*
        """

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
