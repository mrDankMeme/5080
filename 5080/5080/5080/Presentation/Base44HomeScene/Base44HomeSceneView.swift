import SwiftUI

struct Base44HomeSceneView: View {
    @ObservedObject var viewModel: Base44HomeSceneViewModel

    let onTapSettings: () -> Void
    let onTapPro: () -> Void
    let onTapCreate: () -> Void
    let onTapProject: (SiteMakerProjectSummary) -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 30.scale) {
                    headerView
                    titleView
                    composerCard
                    projectsSection
                }
                .frame(minHeight: proxy.size.height - 1.scale, alignment: .top)
                .padding(.horizontal, 16.scale)
                .padding(.top, 0.scale)
                .padding(.bottom, max(28.scale, proxy.safeAreaInsets.bottom + 18.scale))
            }
            .background(backgroundView.ignoresSafeArea())
        }
    }
}

private extension Base44HomeSceneView {
    var backgroundView: some View {
        LinearGradient(
            colors: [
                Tokens.Color.base44SkyBlue,
                Tokens.Color.surfaceWhite,
                Tokens.Color.base44WarmCream
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var headerView: some View {
        HStack(spacing: 12.scale) {
            HStack(spacing: 6.2.scale) {
                Base44LogoMarkView()
                    .frame(width: 25.6.scale, height: 25.6.scale)

                Text("Base44")
                    .font(Tokens.Font.bold32)
                    .foregroundStyle(Tokens.Color.base44BrandOrange)
                    .lineLimit(1)
            }

            Spacer(minLength: 12.scale)

            headerIconButton(
                systemName: "gearshape.fill",
                foregroundColor: Tokens.Color.inkPrimary,
                backgroundColor: Tokens.Color.surfaceWhite.opacity(0.96),
                action: onTapSettings
            )

            Button(action: onTapPro) {
                HStack(spacing: 6.scale) {
                    Image(systemName: "sparkles")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13.scale, height: 13.scale)

                    Text(viewModel.headerBadgeTitle)
                        .font(Tokens.Font.bold15)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(Tokens.Color.surfaceWhite)
                .padding(.horizontal, 14.scale)
                .frame(height: 36.scale)
                .background(Tokens.Color.base44BrandOrange)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 0.scale)
    }

    var titleView: some View {
        Text("Turn Ideas into Apps & Websites")
            .font(Tokens.Font.bold24)
            .foregroundStyle(Tokens.Color.inkPrimary)
            .multilineTextAlignment(.leading)
    }

    var composerCard: some View {
        VStack(alignment: .leading, spacing: 16.scale) {
            ZStack(alignment: .topLeading) {
                if viewModel.draftPrompt.isEmpty {
                    Text("Describe what you want to create...")
                        .font(Tokens.Font.regular17)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .padding(.horizontal, 4.scale)
                        .padding(.vertical, 8.scale)
                }

                TextEditor(text: $viewModel.draftPrompt)
                    .font(Tokens.Font.regular17)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 104.scale)
                    .padding(.horizontal, -4.scale)
                    .padding(.vertical, -8.scale)
                    .background(Color.clear)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
            }

            if !viewModel.attachments.isEmpty {
                PendingAttachmentsStripView(
                    attachments: viewModel.attachments,
                    onRemove: { attachment in
                        viewModel.removeAttachment(id: attachment.id)
                    }
                )
            }

            HStack(spacing: 12.scale) {
                BuilderAttachmentPickerButton(
                    onImported: { attachments in
                        viewModel.appendAttachments(attachments)
                    },
                    onError: { _ in }
                ) {
                    Circle()
                        .fill(Tokens.Color.surfaceWhite)
                        .frame(width: 42.scale, height: 42.scale)
                        .overlay {
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18.scale, height: 18.scale)
                                .foregroundStyle(Tokens.Color.inkPrimary)
                        }
                }

                Spacer(minLength: 0.scale)

                Button(action: onTapCreate) {
                    HStack(spacing: 8.scale) {
                        Image(systemName: "wand.and.stars")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14.scale, height: 14.scale)

                        Text("Create")
                            .font(Tokens.Font.semibold16)
                    }
                    .foregroundStyle(Tokens.Color.surfaceWhite)
                    .padding(.horizontal, 18.scale)
                    .frame(height: 40.scale)
                    .background(
                        viewModel.canCreate
                            ? Tokens.Color.base44BrandOrange
                            : Tokens.Color.base44BrandOrange.opacity(0.42)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canCreate)
            }
        }
        .padding(16.scale)
        .background(Tokens.Color.surfaceWhite.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24.scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24.scale, style: .continuous)
                .stroke(Tokens.Color.base44Border, lineWidth: 1.scale)
        }
        .shadow(color: Tokens.Color.inkPrimary.opacity(0.08), radius: 18.scale, y: 8.scale)
    }

    var projectsSection: some View {
        VStack(alignment: .leading, spacing: 16.scale) {
            HStack(spacing: 12.scale) {
                Text("Your projects")
                    .font(Tokens.Font.bold18)
                    .foregroundStyle(Tokens.Color.inkPrimary)

                if viewModel.isLoadingProjects {
                    ProgressView()
                        .tint(Tokens.Color.base44BrandOrange)
                }
            }

            if viewModel.projects.isEmpty {
                emptyProjectsView
            } else {
                VStack(spacing: 12.scale) {
                    ForEach(viewModel.projects) { project in
                        Base44ProjectRowView(project: project) {
                            onTapProject(project)
                        }
                    }
                }
            }

            if let errorText = viewModel.projectsErrorText, viewModel.projects.isEmpty {
                Text(errorText)
                    .font(Tokens.Font.regular13)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    var emptyProjectsView: some View {
        VStack(spacing: 12.scale) {
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 28.scale, height: 28.scale)
                .foregroundStyle(Tokens.Color.base44BrandOrange)

            Text("No Projects Yet")
                .font(Tokens.Font.bold18)
                .foregroundStyle(Tokens.Color.inkPrimary)

            Text("Start creating your first website or app to see it here")
                .font(Tokens.Font.regular16)
                .foregroundStyle(Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260.scale)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34.scale)
    }

    func headerIconButton(
        systemName: String,
        foregroundColor: Color,
        backgroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Circle()
                .fill(backgroundColor)
                .frame(width: 36.scale, height: 36.scale)
                .overlay {
                    Image(systemName: systemName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16.scale, height: 16.scale)
                        .foregroundStyle(foregroundColor)
                }
        }
        .buttonStyle(.plain)
    }
}
