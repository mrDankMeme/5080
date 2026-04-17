import Foundation

struct SiteMakerAuthorizedContext {
    let baseURLString: String
    let accessToken: String
}

protocol SiteMakerAuthorizationProviding: AnyObject {
    func authorizedContext() async throws -> SiteMakerAuthorizedContext
}

enum SiteMakerAuthorizationError: LocalizedError {
    case invalidAnonymousUserID
    case missingAccessToken
    case backend(statusCode: Int, message: String)
    case invalidBaseURL
    case invalidResponse
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAnonymousUserID:
            return "Anonymous user id must be a UUID."
        case .missingAccessToken:
            return "Access token is empty."
        case .backend(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .invalidBaseURL:
            return "Invalid SiteMaker base URL."
        case .invalidResponse:
            return "Invalid SiteMaker response."
        case .transport(let error), .decoding(let error):
            return error.localizedDescription
        }
    }
}

final class SiteMakerAuthorizationProvider: SiteMakerAuthorizationProviding {
    private let session: URLSession
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var storedSession: SiteMakerSession

    init(
        session: URLSession = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.session = session
        self.userDefaults = userDefaults
        self.storedSession = SiteMakerSessionStore.load()

        if self.storedSession.baseURLString.trimmed.isEmpty {
            self.storedSession.baseURLString = SiteMakerConfiguration.baseURLString
        }

        syncAnonymousUserIDWithSharedStoreIfNeeded()
    }

    func authorizedContext() async throws -> SiteMakerAuthorizedContext {
        let authenticatedSession = try await ensureAuthenticatedSession()
        let accessToken = authenticatedSession.accessToken.trimmed

        guard !accessToken.isEmpty else {
            throw SiteMakerAuthorizationError.missingAccessToken
        }

        SiteMakerDebugLogger.logAuth(
            "Authorized context ready. anonymousUserID=\(authenticatedSession.anonymousUserID)"
        )

        return SiteMakerAuthorizedContext(
            baseURLString: authenticatedSession.baseURLString,
            accessToken: accessToken
        )
    }
}

private extension SiteMakerAuthorizationProvider {
    func ensureAuthenticatedSession() async throws -> SiteMakerSession {
        let anonymousUserID = resolveAnonymousUserID()

        if let accessToken = storedSession.accessToken.nilIfEmpty,
           await isAccessTokenValid(accessToken) {
            SiteMakerDebugLogger.logAuth("Using existing access token for \(anonymousUserID).")
            return storedSession
        }

        if try await refreshTokensIfPossible(),
           let accessToken = storedSession.accessToken.nilIfEmpty,
           await isAccessTokenValid(accessToken) {
            SiteMakerDebugLogger.logAuth("Using refreshed access token for \(anonymousUserID).")
            return storedSession
        }

        try await registerOrLogin(anonymousUserID: anonymousUserID)
        return storedSession
    }

    func isAccessTokenValid(_ accessToken: String) async -> Bool {
        do {
            let response = try await performRequest(
                method: "GET",
                path: "/api/auth/me",
                authToken: accessToken
            )
            let isValid = (200..<300).contains(response.statusCode)
            if !isValid {
                SiteMakerDebugLogger.logAuth(
                    "Access token validation failed with status \(response.statusCode)."
                )
            }
            return isValid
        } catch {
            SiteMakerDebugLogger.logAuth(
                "Access token validation transport error: \(error.localizedDescription)"
            )
            return false
        }
    }

    func refreshTokensIfPossible() async throws -> Bool {
        let refreshToken = storedSession.refreshToken.trimmed
        guard !refreshToken.isEmpty else { return false }

        SiteMakerDebugLogger.logAuth("Refreshing SiteMaker tokens.")

        let response = try await performRequest(
            method: "POST",
            path: "/api/auth/refresh",
            queryItems: [URLQueryItem(name: "refresh_token", value: refreshToken)]
        )

        guard (200..<300).contains(response.statusCode) else {
            SiteMakerDebugLogger.logAuth(
                "Refresh request failed with status \(response.statusCode)."
            )
            return false
        }

        let tokens = try decode(SiteMakerTokenResponse.self, from: response.data)
        apply(tokens: tokens)
        SiteMakerDebugLogger.logAuth("Refresh succeeded.")
        return true
    }

    func registerOrLogin(anonymousUserID: String) async throws {
        let email = try anonymousEmail(for: anonymousUserID)
        let password = storedSession.password.nilIfEmpty ?? SiteMakerConfiguration.anonymousPassword

        let registerPayload = SiteMakerRegisterRequest(
            email: email,
            password: password,
            display_name: nil
        )

        let registerResponse = try await performRequest(
            method: "POST",
            path: "/api/auth/register",
            jsonBody: try encode(registerPayload)
        )

        if registerResponse.statusCode == 201 {
            let tokens = try decode(SiteMakerTokenResponse.self, from: registerResponse.data)
            storedSession.anonymousUserID = anonymousUserID
            storedSession.password = password
            apply(tokens: tokens)
            SiteMakerDebugLogger.logAuth(
                "Registered anonymous SiteMaker user \(anonymousUserID)."
            )
            return
        }

        if registerResponse.statusCode == 409 {
            SiteMakerDebugLogger.logAuth(
                "Anonymous user \(anonymousUserID) already exists. Falling back to login."
            )
            let loginPayload = SiteMakerLoginRequest(
                email: email,
                password: password
            )

            let loginResponse = try await performRequest(
                method: "POST",
                path: "/api/auth/login",
                jsonBody: try encode(loginPayload)
            )

            guard (200..<300).contains(loginResponse.statusCode) else {
                throw SiteMakerAuthorizationError.backend(
                    statusCode: loginResponse.statusCode,
                    message: errorMessage(from: loginResponse.data) ?? "Unknown backend error."
                )
            }

            let tokens = try decode(SiteMakerTokenResponse.self, from: loginResponse.data)
            storedSession.anonymousUserID = anonymousUserID
            storedSession.password = password
            apply(tokens: tokens)
            SiteMakerDebugLogger.logAuth(
                "Login succeeded for anonymous SiteMaker user \(anonymousUserID)."
            )
            return
        }

        throw SiteMakerAuthorizationError.backend(
            statusCode: registerResponse.statusCode,
            message: errorMessage(from: registerResponse.data) ?? "Unknown backend error."
        )
    }

    func resolveAnonymousUserID() -> String {
        let resolvedUserID = AppUserIdentityConfiguration.resolvedUserID(userDefaults: userDefaults)
        SiteMakerDebugLogger.logAuth("Resolved app userId=\(resolvedUserID)")
        adoptSharedAnonymousUserIDIfNeeded(resolvedUserID)
        return resolvedUserID
    }

    func anonymousEmail(for anonymousUserID: String) throws -> String {
        guard let validatedID = validatedAnonymousUserID(from: anonymousUserID) else {
            throw SiteMakerAuthorizationError.invalidAnonymousUserID
        }

        return "\(validatedID)@not-real-email"
    }

    func validatedAnonymousUserID(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let cleaned = rawValue.trimmed.lowercased()
        let resolvedValue: String

        if cleaned.hasSuffix("@not-real-email") {
            resolvedValue = cleaned.replacingOccurrences(
                of: "@not-real-email",
                with: ""
            )
        } else {
            resolvedValue = cleaned
        }

        guard UUID(uuidString: resolvedValue) != nil else {
            return nil
        }

        return resolvedValue
    }

    func apply(tokens: SiteMakerTokenResponse) {
        storedSession.accessToken = tokens.access_token
        storedSession.refreshToken = tokens.refresh_token
        storedSession.tokenType = tokens.token_type
        persistSession()
    }

    func persistSession() {
        SiteMakerSessionStore.save(storedSession)
    }

    func performRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        authToken: String? = nil,
        jsonBody: Data? = nil
    ) async throws -> (statusCode: Int, data: Data) {
        let url = try makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let authToken, !authToken.trimmed.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let jsonBody {
            request.httpBody = jsonBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        SiteMakerDebugLogger.logRequest(request)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SiteMakerAuthorizationError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SiteMakerAuthorizationError.invalidResponse
        }

        SiteMakerDebugLogger.logResponse(
            url: request.url,
            statusCode: httpResponse.statusCode,
            data: data
        )

        return (httpResponse.statusCode, data)
    }

    func syncAnonymousUserIDWithSharedStoreIfNeeded() {
        let resolvedUserID = AppUserIdentityConfiguration.resolvedUserID(userDefaults: userDefaults)
        adoptSharedAnonymousUserIDIfNeeded(resolvedUserID)
    }

    func adoptSharedAnonymousUserIDIfNeeded(_ sharedAnonymousUserID: String) {
        let currentStoredUserID = validatedAnonymousUserID(from: storedSession.anonymousUserID)
        guard currentStoredUserID != sharedAnonymousUserID else {
            if storedSession.anonymousUserID != sharedAnonymousUserID {
                storedSession.anonymousUserID = sharedAnonymousUserID
                persistSession()
            }
            return
        }

        SiteMakerDebugLogger.logAuth(
            "Switching SiteMaker anonymous user from \(currentStoredUserID ?? "<empty>") to shared \(sharedAnonymousUserID)."
        )
        storedSession.anonymousUserID = sharedAnonymousUserID
        storedSession.accessToken = ""
        storedSession.refreshToken = ""
        persistSession()
    }

    func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: storedSession.baseURLString) else {
            throw SiteMakerAuthorizationError.invalidBaseURL
        }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        components.path = basePath.isEmpty
            ? "/" + trimmedPath
            : "/" + basePath + "/" + trimmedPath
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw SiteMakerAuthorizationError.invalidBaseURL
        }

        return url
    }

    func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw SiteMakerAuthorizationError.transport(error)
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SiteMakerAuthorizationError.decoding(error)
        }
    }

    func errorMessage(from data: Data) -> String? {
        if let apiError = try? decoder.decode(SiteMakerAPIError.self, from: data) {
            return apiError.detail.nilIfEmpty
        }

        guard let rawValue = String(data: data, encoding: .utf8)?.trimmed else {
            return nil
        }

        return rawValue.nilIfEmpty
    }
}

private struct SiteMakerSession: Codable {
    var baseURLString: String
    var anonymousUserID: String
    var password: String
    var accessToken: String
    var refreshToken: String
    var tokenType: String
}

private enum SiteMakerSessionStore {
    static let sessionKey = "site-maker-builder-session"

    static func load() -> SiteMakerSession {
        guard
            let data = UserDefaults.standard.data(forKey: sessionKey),
            let session = try? JSONDecoder().decode(SiteMakerSession.self, from: data)
        else {
            return SiteMakerSession(
                baseURLString: SiteMakerConfiguration.baseURLString,
                anonymousUserID: "",
                password: SiteMakerConfiguration.anonymousPassword,
                accessToken: "",
                refreshToken: "",
                tokenType: "bearer"
            )
        }

        return session
    }

    static func save(_ session: SiteMakerSession) {
        guard let data = try? JSONEncoder().encode(session) else {
            return
        }

        UserDefaults.standard.set(data, forKey: sessionKey)
    }
}

private struct SiteMakerRegisterRequest: Encodable {
    let email: String
    let password: String
    let display_name: String?
}

private struct SiteMakerLoginRequest: Encodable {
    let email: String
    let password: String
}

private struct SiteMakerTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let token_type: String
}

private struct SiteMakerAPIError: Decodable {
    let detail: String
}

enum SiteMakerDebugLogger {
    static func logAuth(_ message: String) {
        #if DEBUG
        print("[5080API][Auth] \(message)")
        #endif
    }

    static func logRequest(_ request: URLRequest) {
        #if DEBUG
        print("--------------------------------------------------")
        print("[5080API][Request] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "<unknown>")")
        print("[5080API][Request] headers: \(sanitizedHeaders(from: request))")
        print("[5080API][Request] body: \(bodyDescription(from: request.httpBody))")
        #endif
    }

    static func logResponse(
        url: URL?,
        statusCode: Int,
        data: Data
    ) {
        #if DEBUG
        print("[5080API][Response] \(statusCode) \(url?.absoluteString ?? "<unknown>")")
        print("[5080API][Response] body: \(responseDescription(from: data))")
        print("--------------------------------------------------")
        #endif
    }
}

private extension SiteMakerDebugLogger {
    static func sanitizedHeaders(from request: URLRequest) -> [String: String] {
        (request.allHTTPHeaderFields ?? [:]).reduce(into: [:]) { partialResult, element in
            if element.key.caseInsensitiveCompare("Authorization") == .orderedSame {
                partialResult[element.key] = maskAuthorizationValue(element.value)
            } else {
                partialResult[element.key] = element.value
            }
        }
    }

    static func maskAuthorizationValue(_ value: String) -> String {
        guard value.hasPrefix("Bearer ") else {
            return value
        }

        let token = String(value.dropFirst("Bearer ".count))
        let maskedToken = maskToken(token)
        return "Bearer \(maskedToken)"
    }

    static func maskToken(_ token: String) -> String {
        guard token.count > 9 else {
            return token
        }

        let prefix = token.prefix(6)
        let suffix = token.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    static func bodyDescription(from data: Data?) -> String {
        guard let data, !data.isEmpty else {
            return "<empty>"
        }

        return responseDescription(from: data)
    }

    static func responseDescription(from data: Data) -> String {
        guard !data.isEmpty else {
            return "<empty>"
        }

        if
            let object = try? JSONSerialization.jsonObject(with: data),
            let formattedData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
            let formattedString = String(data: formattedData, encoding: .utf8)
        {
            return formattedString
        }

        if let stringValue = String(data: data, encoding: .utf8) {
            return stringValue
        }

        return "<\(data.count) bytes>"
    }
}
