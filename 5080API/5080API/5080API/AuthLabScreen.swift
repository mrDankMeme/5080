import SwiftUI

struct AuthLabScreen: View {
    @StateObject private var viewModel = AuthLabViewModel()

    private let actionColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerView
                connectionCard
                authCard
                balanceCard
                tokensCard
                responseCard
            }
            .padding(14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("5080 Auth Lab")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Request in progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Status: \(viewModel.statusLine)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                metricPill(title: "backend user", value: viewModel.backendUserID)
                metricPill(title: "credits", value: viewModel.creditsText)
                metricPill(title: "token type", value: viewModel.tokenType)
            }
        }
    }

    private var connectionCard: some View {
        LabCard(title: "Connection") {
            VStack(alignment: .leading, spacing: 10) {
                LabLabeledField(label: "base URL") {
                    TextField("https://roboapp.cc", text: $viewModel.baseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Text("Path prefix `/api/...` уже зашит в кнопках ниже, так что здесь достаточно домена.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var authCard: some View {
        LabCard(title: "Auth") {
            VStack(alignment: .leading, spacing: 10) {
                LabLabeledField(label: "anonymous user id") {
                    TextField("550e8400-e29b-41d4-a716-446655440000", text: $viewModel.userIdentifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Text("Derived email: \(viewModel.derivedEmail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Button("Generate new UUID") {
                    viewModel.generateNewUserIdentifier()
                }
                .buttonStyle(.bordered)

                LabLabeledField(label: "password") {
                    SecureField("TestPass123", text: $viewModel.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Text("Backend ожидает пароль минимум 8 символов, с uppercase и цифрой.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                LabLabeledField(label: "display name") {
                    TextField("Optional", text: $viewModel.displayName)
                        .textInputAutocapitalization(.words)
                }

                LazyVGrid(columns: actionColumns, spacing: 8) {
                    ActionButton(title: "POST /register", isDisabled: viewModel.isLoading) {
                        Task { await viewModel.register() }
                    }

                    ActionButton(title: "POST /login", isDisabled: viewModel.isLoading) {
                        Task { await viewModel.login() }
                    }

                    ActionButton(title: "POST /refresh", isDisabled: viewModel.isLoading) {
                        Task { await viewModel.refreshTokens() }
                    }
                }
            }
        }
    }

    private var balanceCard: some View {
        LabCard(title: "Balance") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Баланс кредитов и валидность `access_token` проверяются через `GET /api/auth/me`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ActionButton(title: "Check balance via GET /me", isDisabled: viewModel.isLoading) {
                    Task { await viewModel.fetchCurrentUser() }
                }

                HStack(spacing: 12) {
                    metricPill(title: "credits", value: viewModel.creditsText)
                    metricPill(title: "email", value: viewModel.currentUserEmail)
                }

                LabLabeledField(label: "created at") {
                    Text(viewModel.currentUserCreatedAt)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var tokensCard: some View {
        LabCard(title: "Tokens") {
            VStack(alignment: .leading, spacing: 10) {
                LabLabeledField(label: "access token") {
                    tokenEditor(text: $viewModel.accessToken)
                }

                LabLabeledField(label: "refresh token") {
                    tokenEditor(text: $viewModel.refreshToken)
                }

                Text("`access_token` проверяется через `GET /me`, `refresh_token` проверяется через `POST /refresh`. Токены сохраняются локально между запусками.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var responseCard: some View {
        LabCard(title: "Last Response") {
            ScrollView(.horizontal) {
                Text(viewModel.lastResponseText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 220, alignment: .topLeading)
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func tokenEditor(text: Binding<String>) -> some View {
        TextEditor(text: text)
            .font(.system(.caption, design: .monospaced))
            .scrollContentBackground(.hidden)
            .frame(minHeight: 82)
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

private struct LabCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct LabLabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            content
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct ActionButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled)
    }
}

#Preview {
    NavigationStack {
        AuthLabScreen()
    }
}
