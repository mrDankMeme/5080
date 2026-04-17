import Foundation

struct ServicePricesResponse: Decodable {
    let error: Bool
    let code: String?
    let message: String?
    let data: ServicePricesData?
}

struct ServicePricesData: Decodable {
    let pricesByKey: [String: Int]
    let klingPrice: [KlingModelPrice]

    func price(for key: String) -> Int? {
        pricesByKey[key]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var parsedPrices: [String: Int] = [:]
        var parsedKlingPrice: [KlingModelPrice] = []

        for key in container.allKeys {
            if key.stringValue == "klingPrice" {
                parsedKlingPrice = (try? container.decode([KlingModelPrice].self, forKey: key)) ?? []
                continue
            }

            if let price = try? container.decode(Int.self, forKey: key) {
                parsedPrices[key.stringValue] = price
            }
        }

        self.pricesByKey = parsedPrices
        self.klingPrice = parsedKlingPrice
    }
}

struct KlingModelPrice: Decodable, Hashable {
    let model: String
    let seconds: [KlingDurationPrice]
}

struct KlingDurationPrice: Decodable, Hashable {
    let duration: Int
    let price: Int
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

extension ServicePricesData {

    func klingPrice(model: String, duration: Int) -> Int? {
        klingPrice
            .first { $0.model == model }?
            .seconds
            .first { $0.duration == duration }?
            .price
    }

}
