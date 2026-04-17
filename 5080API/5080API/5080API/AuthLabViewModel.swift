import Combine
import Foundation

enum AuthLabError: LocalizedError {
    case invalidAnonymousUserID
    case emptyPassword
    case missingRefreshToken
    case missingAccessToken
    case backend(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidAnonymousUserID:
            return "Anonymous user id must be a valid UUID or {UUID}@not-real-email."
        case .emptyPassword:
            return "Password is required."
        case .missingRefreshToken:
            return "Refresh token is empty. Register or login first."
        case .missingAccessToken:
            return "Access token is empty. Register, login, or refresh first."
        case .backend(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        }
    }
}

@MainActor
final class AuthLabViewModel: ObservableObject {
    @Published var baseURLString: String {
        didSet { persistSession() }
    }
    @Published var userIdentifier: String {
        didSet { persistSession() }
    }
    @Published var password: String {
        didSet { persistSession() }
    }
    @Published var displayName: String {
        didSet { persistSession() }
    }
    @Published var accessToken: String {
        didSet { persistSession() }
    }
    @Published var refreshToken: String {
        didSet { persistSession() }
    }
    @Published private(set) var tokenType: String
    @Published private(set) var currentUser: AuthCurrentUser?
    @Published private(set) var isLoading = false
    @Published private(set) var statusLine = "Ready"
    @Published private(set) var lastResponseText = "No requests yet."

    private let service: SiteMakerAuthService

    init(service: SiteMakerAuthService? = nil) {
        let session = AuthLabStorage.load()
        self.service = service ?? SiteMakerAuthService()
        self.baseURLString = session.baseURLString
        self.userIdentifier = session.userIdentifier
        self.password = session.password
        self.displayName = session.displayName
        self.accessToken = session.accessToken
        self.refreshToken = session.refreshToken
        self.tokenType = session.tokenType
    }

    var derivedEmail: String {
        (try? resolvedEmail()) ?? "Enter a UUID to build {UUID}@not-real-email"
    }

    var backendUserID: String {
        currentUser?.id ?? "-"
    }

    var creditsText: String {
        currentUser.map { String($0.credits) } ?? "-"
    }

    var currentUserEmail: String {
        currentUser?.email ?? "-"
    }

    var currentUserCreatedAt: String {
        currentUser?.created_at ?? "-"
    }

    func generateNewUserIdentifier() {
        userIdentifier = UUID().uuidString.lowercased()
        statusLine = "Generated a fresh anonymous user id."
    }

    func register() async {
        do {
            try ensurePassword()
            let email = try resolvedEmail()
            let payload = AuthRegisterRequest(
                email: email,
                password: password.trimmed,
                display_name: displayName.nilIfEmpty
            )

            let response = try await performRequest(
                title: "Registering \(email)...",
                method: .post,
                path: "/api/auth/register",
                body: try service.makeJSONBody(payload)
            )

            let tokens = try parseSuccessfulResponse(AuthTokenResponse.self, from: response)
            applyTokens(tokens)
            statusLine = "Register succeeded. Tokens saved for \(email)."
        } catch {
            handle(error, fallback: "Register failed.")
        }
    }

    func login() async {
        do {
            try ensurePassword()
            let email = try resolvedEmail()
            let payload = AuthLoginRequest(email: email, password: password.trimmed)

            let response = try await performRequest(
                title: "Logging in \(email)...",
                method: .post,
                path: "/api/auth/login",
                body: try service.makeJSONBody(payload)
            )

            let tokens = try parseSuccessfulResponse(AuthTokenResponse.self, from: response)
            applyTokens(tokens)
            statusLine = "Login succeeded. Tokens refreshed for \(email)."
        } catch {
            handle(error, fallback: "Login failed.")
        }
    }

    func refreshTokens() async {
        do {
            let cleanedRefreshToken = refreshToken.trimmed
            guard !cleanedRefreshToken.isEmpty else {
                throw AuthLabError.missingRefreshToken
            }

            let response = try await performRequest(
                title: "Refreshing tokens...",
                method: .post,
                path: "/api/auth/refresh",
                queryItems: [URLQueryItem(name: "refresh_token", value: cleanedRefreshToken)]
            )

            let tokens = try parseSuccessfulResponse(AuthTokenResponse.self, from: response)
            applyTokens(tokens)
            statusLine = "Refresh succeeded. New token pair stored."
        } catch {
            handle(error, fallback: "Refresh failed.")
        }
    }

    func fetchCurrentUser() async {
        do {
            let cleanedAccessToken = accessToken.trimmed
            guard !cleanedAccessToken.isEmpty else {
                throw AuthLabError.missingAccessToken
            }

            let response = try await performRequest(
                title: "Loading current user...",
                method: .get,
                path: "/api/auth/me",
                authToken: cleanedAccessToken
            )

            let user = try parseSuccessfulResponse(AuthCurrentUser.self, from: response)
            currentUser = user
            statusLine = "Loaded current user \(user.id). Credits: \(user.credits)."
        } catch {
            handle(error, fallback: "Fetching current user failed.")
        }
    }

    private func performRequest(
        title: String,
        method: SiteMakerHTTPMethod,
        path: String,
        authToken: String? = nil,
        queryItems: [URLQueryItem] = [],
        body: SiteMakerRequestBody = .none
    ) async throws -> SiteMakerRawResponse {
        isLoading = true
        statusLine = title

        defer {
            isLoading = false
        }

        let response = try await service.sendRequest(
            baseURLString: baseURLString.trimmed,
            method: method,
            path: path,
            authToken: authToken,
            queryItems: queryItems,
            body: body
        )

        lastResponseText = service.responseText(from: response)
        return response
    }

    private func parseSuccessfulResponse<T: Decodable>(_ type: T.Type, from response: SiteMakerRawResponse) throws -> T {
        guard response.isSuccess else {
            let message = service.errorMessage(from: response) ?? "Unknown backend error."
            throw AuthLabError.backend(statusCode: response.statusCode, message: message)
        }

        return try service.decode(type, from: response)
    }

    private func applyTokens(_ tokens: AuthTokenResponse) {
        accessToken = tokens.access_token
        refreshToken = tokens.refresh_token
        tokenType = tokens.token_type
        persistSession()
    }

    private func resolvedEmail() throws -> String {
        let cleaned = userIdentifier.trimmed.lowercased()

        if cleaned.hasSuffix("@not-real-email") {
            let prefix = cleaned.replacingOccurrences(of: "@not-real-email", with: "")
            guard UUID(uuidString: prefix) != nil else {
                throw AuthLabError.invalidAnonymousUserID
            }
            userIdentifier = prefix
            return "\(prefix)@not-real-email"
        }

        guard UUID(uuidString: cleaned) != nil else {
            throw AuthLabError.invalidAnonymousUserID
        }

        return "\(cleaned)@not-real-email"
    }

    private func ensurePassword() throws {
        guard !password.trimmed.isEmpty else {
            throw AuthLabError.emptyPassword
        }
    }

    private func persistSession() {
        AuthLabStorage.save(
            AuthLabSession(
                baseURLString: baseURLString,
                userIdentifier: userIdentifier,
                password: password,
                displayName: displayName,
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: tokenType
            )
        )
    }

    private func handle(_ error: Error, fallback: String) {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            statusLine = description
        } else {
            statusLine = fallback
        }
    }
}
