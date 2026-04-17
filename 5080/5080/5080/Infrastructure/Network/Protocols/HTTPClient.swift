import Foundation

@MainActor
protocol HTTPClient: AnyObject {
    func send<T: Decodable>(_ request: HTTPRequest, responseType: T.Type) async throws -> T
    func sendData(_ request: HTTPRequest) async throws -> Data
}
