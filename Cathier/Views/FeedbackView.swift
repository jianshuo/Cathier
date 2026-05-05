import SwiftUI

struct FeedbackView: View {
    @Environment(LanguageManager.self) private var lm
    @Environment(\.dismiss) private var dismiss

    @AppStorage("feedbackUserName") private var userName: String = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isSubmitting = false
    @State private var submittedURL: URL?
    @State private var errorMessage: String?

    /// Public TestFlight join link. Generate it in App Store Connect →
    /// TestFlight → External Testing group → "Enable Public Link", then
    /// paste the URL here. Empty string hides the section.
    private let testFlightPublicLink = "https://testflight.apple.com/join/TwF61E49"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(lm.feedbackNamePlaceholder, text: $userName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                } header: {
                    Text(lm.feedbackNameLabel)
                }

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

                if let url = URL(string: testFlightPublicLink), !testFlightPublicLink.isEmpty {
                    Section {
                        Link(destination: url) {
                            HStack(spacing: 12) {
                                Image(systemName: "airplane.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.cathierAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lm.aboutTestFlightTitle)
                                        .foregroundStyle(.primary)
                                    Text(lm.aboutTestFlightSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                if let url = submittedURL {
                    Section {
                        Link(lm.feedbackViewIssue, destination: url)
                            .foregroundColor(.cathierAccent)
                    } header: {
                        Text(lm.feedbackSuccess)
                            .foregroundColor(.cathierAccent)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
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
                    .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty ||
                              title.trimmingCharacters(in: .whitespaces).isEmpty ||
                              bodyText.trimmingCharacters(in: .whitespaces).isEmpty ||
                              isSubmitting)
                }
            }
        }
    }

    private func submitFeedback() {
        isSubmitting = true
        errorMessage = nil
        let trimmedName = userName.trimmingCharacters(in: .whitespaces)
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespaces)
        userName = trimmedName

        Task {
            do {
                let url = try await GitHubService.createFeedbackIssue(
                    title: trimmedTitle,
                    body: trimmedBody,
                    submittedBy: trimmedName
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
