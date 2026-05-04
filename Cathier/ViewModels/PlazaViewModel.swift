import CloudKit
import Foundation
import Observation

@Observable
final class PlazaViewModel {
    var posts: [PlazaPost] = []
    var isLoading = false
    var error: String?

    private let ck = CloudKitService.shared

    func load(force: Bool = false) async {
        guard force || !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await ck.fetchPlazaPosts()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func post(_ plazaPost: PlazaPost) async throws {
        try await ck.savePlazaPost(plazaPost)
        if !posts.contains(where: { $0.id == plazaPost.id }) {
            posts.insert(plazaPost, at: 0)
        }
    }

    func remove(post: PlazaPost) async {
        do {
            try await ck.deletePlazaPost(id: post.id)
            posts.removeAll { $0.id == post.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
