import SwiftUI
import PhotosUI

struct FeedbackView: View {
    @Environment(LanguageManager.self) private var lm
    @Environment(\.dismiss) private var dismiss

    @AppStorage("feedbackUserName") private var userName: String = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isSubmitting = false
    @State private var submittedURL: URL?
    @State private var errorMessage: String?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachedImages: [UIImage] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(lm.feedbackNamePlaceholder, text: $userName)
                        .textInputAutocapitalization(.words)
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lm.feedbackBodyFooter)
                        Link(lm.feedbackViewAllIssues,
                             destination: URL(string: "https://github.com/jianshuo/Cathier/issues")!)
                            .foregroundColor(.cathierAccent)
                    }
                    .font(.caption)
                }

                Section {
                    if !attachedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(attachedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: attachedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipped()
                                            .cornerRadius(8)
                                        Button {
                                            attachedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.cathierAccent)
                                                .background(Color.white.clipShape(Circle()))
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if attachedImages.count < 3 {
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 3 - attachedImages.count,
                            matching: .images
                        ) {
                            Label(lm.feedbackScreenshotAdd, systemImage: "photo.badge.plus")
                                .foregroundColor(.cathierAccent)
                        }
                        .onChange(of: selectedPhotos) { _, items in
                            Task {
                                for item in items {
                                    guard attachedImages.count < 3 else { break }
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        attachedImages.append(image)
                                    }
                                }
                                selectedPhotos = []
                            }
                        }
                    }
                } header: {
                    Text(lm.feedbackScreenshotLabel)
                } footer: {
                    Text(lm.feedbackScreenshotFooter)
                        .font(.caption)
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespaces)
        let trimmedName = userName.trimmingCharacters(in: .whitespaces)
        let images = attachedImages

        Task {
            do {
                let url = try await GitHubService.createFeedbackIssue(
                    title: trimmedTitle,
                    body: trimmedBody,
                    images: images,
                    submittedBy: trimmedName
                )
                await MainActor.run {
                    submittedURL = url
                    title = ""
                    bodyText = ""
                    attachedImages = []
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
