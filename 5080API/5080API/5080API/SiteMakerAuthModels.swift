import Foundation

enum SiteMakerHTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct SiteMakerRawResponse {
    let method: SiteMakerHTTPMethod
    let url: URL
    let statusCode: Int
    let data: Data

    var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}

struct AuthRegisterRequest: Encodable {
    let email: String
    let password: String
    let display_name: String?
}

struct AuthLoginRequest: Encodable {
    let email: String
    let password: String
}

struct AuthTokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let token_type: String
}

struct AuthCurrentUser: Codable {
    let id: String
    let email: String
    let display_name: String?
    let credits: Int
    let created_at: String
}

struct APIErrorResponse: Decodable {
    let detail: String
}

struct AuthLabSession: Codable {
    var baseURLString: String
    var userIdentifier: String
    var password: String
    var displayName: String
    var accessToken: String
    var refreshToken: String
    var tokenType: String
}

enum AuthLabDefaults {
    static let baseURLString = "https://roboapp.cc"
    static let legacyBaseURLStrings = [
        "https://sitemaker.cloud"
    ]
    static let password = "TestPass123"

    static func makeSession() -> AuthLabSession {
        AuthLabSession(
            baseURLString: baseURLString,
            userIdentifier: UUID().uuidString.lowercased(),
            password: password,
            displayName: "",
            accessToken: "",
            refreshToken: "",
            tokenType: "bearer"
        )
    }
}

enum AuthLabStorage {
    private static let sessionKey = "site-maker-auth-lab-session"

    static func load() -> AuthLabSession {
        guard
            let data = UserDefaults.standard.data(forKey: sessionKey),
            let session = try? JSONDecoder().decode(AuthLabSession.self, from: data)
        else {
            return AuthLabDefaults.makeSession()
        }

        if session.baseURLString.trimmed.isEmpty || AuthLabDefaults.legacyBaseURLStrings.contains(session.baseURLString.trimmed) {
            var migratedSession = session
            migratedSession.baseURLString = AuthLabDefaults.baseURLString
            save(migratedSession)
            return migratedSession
        }

        return session
    }

    static func save(_ session: AuthLabSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: sessionKey)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        let cleaned = trimmed
        return cleaned.isEmpty ? nil : cleaned
    }
}
