import SwiftUI

struct FeedbackView: View {
    @AppStorage("githubToken") private var githubToken = ""
    @Environment(LanguageManager.self) private var lm
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""
    @State private var isSubmitting = false
    @State private var submittedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(lm.feedbackTitlePlaceholder, text: $title)
                        .autocorrectionDisabled()
                } header: {
                    Text(lm.feedbackTitleLabel)
                }

                Section {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 120)
                } header: {
                    Text(lm.feedbackBodyLabel)
                } footer: {
                    Text(lm.feedbackBodyFooter)
                        .font(.caption)
                }

                if let url = submittedURL {
                    Section {
                        Link(lm.feedbackViewIssue, destination: url)
                            .foregroundColor(.orange)
                    } header: {
                        Text(lm.feedbackSuccess)
                            .foregroundColor(.green)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GitHub Personal Access Token")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        SecureField("github_pat_…", text: $githubToken)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(lm.feedbackTokenSection)
                } footer: {
                    Text(lm.feedbackTokenFooter)
                        .font(.caption)
                }
            }
            .navigationTitle(lm.feedbackNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.checkInCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitFeedback()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(lm.feedbackSubmit)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                              bodyText.trimmingCharacters(in: .whitespaces).isEmpty ||
                              githubToken.isEmpty ||
                              isSubmitting)
                }
            }
        }
    }

    private func submitFeedback() {
        isSubmitting = true
        errorMessage = nil
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                let url = try await GitHubService.createFeedbackIssue(
                    title: trimmedTitle,
                    body: trimmedBody,
                    token: githubToken
                )
                await MainActor.run {
                    submittedURL = url
                    title = ""
                    bodyText = ""
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}
