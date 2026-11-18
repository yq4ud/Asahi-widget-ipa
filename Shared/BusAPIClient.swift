import Foundation

final class BusAPIClient {
    static let shared = BusAPIClient()
    private let baseURL = "https://yq4.xsrv.jp/bus.php"

    func fetchBus(from: String, to: String = "", dir: String = "") async throws -> BusAPIResponse {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
            URLQueryItem(name: "dir", value: dir),
            URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970)))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(BusAPIResponse.self, from: data)
    }
}
