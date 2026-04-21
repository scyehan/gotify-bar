import Foundation

struct GotifyMessage: Codable, Identifiable, Equatable {
    let id: UInt
    let appid: UInt
    let message: String
    let title: String
    let priority: Int
    let date: Date

    init(id: UInt, appid: UInt, message: String, title: String, priority: Int = 0, date: Date = .now) {
        self.id = id
        self.appid = appid
        self.message = message
        self.title = title
        self.priority = priority
        self.date = date
    }

    enum CodingKeys: String, CodingKey {
        case id, appid, message, title, priority, date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UInt.self, forKey: .id)
        appid = try container.decode(UInt.self, forKey: .appid)
        message = try container.decode(String.self, forKey: .message)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        date = try container.decode(Date.self, forKey: .date)
    }

    static func == (lhs: GotifyMessage, rhs: GotifyMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct MessageListResponse: Codable {
    let messages: [GotifyMessage]
    let paging: Paging

    struct Paging: Codable {
        let since: UInt?
        let size: Int
        let limit: Int
    }
}

extension JSONDecoder {
    static var gotify: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(string)"
            )
        }
        return decoder
    }
}
