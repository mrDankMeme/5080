import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct BuilderAttachmentPickerButton<Label: View>: View {
    let onImported: ([BuilderAttachmentDraft]) -> Void
    let onError: (String) -> Void
    let label: () -> Label

    @State private var isSourceDialogPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isFileImporterPresented = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    var body: some View {
        Button {
            isSourceDialogPresented = true
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Add attachments",
            isPresented: $isSourceDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Photo Library") {
                isPhotoPickerPresented = true
            }

            Button("Files") {
                isFileImporterPresented = true
            }

            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotoItems,
            maxSelectionCount: 5,
            matching: .any(of: [.images])
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            loadPhotoItems(newItems)
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: true,
            onCompletion: handleImportedFiles
        )
    }
}

private extension BuilderAttachmentPickerButton {
    var allowedFileTypes: [UTType] {
        var result: [UTType] = [.image, .pdf]

        if let svgType = UTType(filenameExtension: "svg") {
            result.append(svgType)
        }

        return result
    }

    func loadPhotoItems(_ items: [PhotosPickerItem]) {
        Task {
            var attachments: [BuilderAttachmentDraft] = []

            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    continue
                }

                let contentType = item.supportedContentTypes.first
                let fileExtension = contentType?.preferredFilenameExtension ?? "jpg"
                let mimeType = contentType?.preferredMIMEType ?? "image/jpeg"
                let fileName = "photo-\(UUID().uuidString.prefix(6)).\(fileExtension)"

                attachments.append(
                    BuilderAttachmentDraft(
                        displayName: fileName,
                        mimeType: mimeType,
                        data: data
                    )
                )
            }

            await MainActor.run {
                selectedPhotoItems = []

                if attachments.isEmpty {
                    onError("Couldn't load the selected photos.")
                    return
                }

                onImported(attachments)
            }
        }
    }

    func handleImportedFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                var attachments: [BuilderAttachmentDraft] = []

                for url in urls {
                    let isSecurityScoped = url.startAccessingSecurityScopedResource()
                    defer {
                        if isSecurityScoped {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    guard let data = try? Data(contentsOf: url) else {
                        continue
                    }

                    let fileType = UTType(filenameExtension: url.pathExtension)
                    let mimeType = fileType?.preferredMIMEType ?? "application/octet-stream"

                    attachments.append(
                        BuilderAttachmentDraft(
                            displayName: url.lastPathComponent,
                            mimeType: mimeType,
                            data: data
                        )
                    )
                }

                await MainActor.run {
                    if attachments.isEmpty {
                        onError("Couldn't import the selected files.")
                        return
                    }

                    onImported(attachments)
                }
            }

        case .failure(let error):
            onError(error.localizedDescription)
        }
    }
}
