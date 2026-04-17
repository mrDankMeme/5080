import Foundation

struct HTTPRequest: Sendable {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?

    init(url: URL, method: HTTPMethod, headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}
