import Foundation

struct TranscribeAPIConfig: Sendable {
    let baseURL: URL
    let apiKey: String
}

enum TranscribeBackendDefaults {
    static let baseURLString = "https://srv.cleanvoice.club/"
    static let apiKey = "QOkAcpXXJKurfMqC9yDr5giV437tb7zim4ZEi9UXWt52AqMzEYA2NrKSZwLOxYP7"
    static let pollingIntervalNanoseconds: UInt64 = 10_000_000_000
    static let maxPollingAttempts = 90
}
