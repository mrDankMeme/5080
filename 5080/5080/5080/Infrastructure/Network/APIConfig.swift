import Foundation

struct APIConfig: Sendable {
    let baseURL: URL
    let bearerToken: String
    let requestTimeout: TimeInterval

    init(baseURL: URL, bearerToken: String, requestTimeout: TimeInterval = 60) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
        self.requestTimeout = requestTimeout
    }
}
