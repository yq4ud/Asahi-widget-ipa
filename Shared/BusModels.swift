import Foundation

struct BusAPIResponse: Codable {
    let status: String
    let stopName: String
    let from: String
    let to: String
    let selectedDir: String
    let directions: [String]
    let scheduledTime: String
    let predictedTime: String
    let delayMinutes: Int
    let stopsAwayText: String
    let nextBus: BusItem
    let buses: [BusItem]
    let detailUrl: String
    let timetableUrl: String?
    let naviUrl: String
    let fetchedAt: String
}

struct BusItem: Codable, Identifiable {
    var id: String { "\(source)-\(scheduledTime)-\(predictedTime)" }
    let source: String
    let scheduledTime: String
    let predictedTime: String
    let delayMinutes: Int
    let stopsAwayText: String

    var isLive: Bool { source == "live" }
    var isDelayed: Bool { delayMinutes > 0 }

    func targetDate(now: Date = Date()) -> Date? {
        let parts = predictedTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = parts[0]
        comps.minute = parts[1]
        comps.second = 0
        guard var target = cal.date(from: comps) else { return nil }
        if target < now.addingTimeInterval(-12 * 3600) {
            target = cal.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target > now ? target : nil
    }
}

struct FavoriteRoute: Codable, Identifiable, Equatable {
    var id: String { "\(from)|\(to)|\(dir)" }
    let from: String
    let to: String
    let dir: String
}

final class RouteStore {
    static let shared = RouteStore()
    private let suiteName = "group.com.yq4uz.asahibusnavi"
    private let favKey = "saved_favorite_routes_v1"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    func loadFavorites() -> [FavoriteRoute] {
        guard let data = defaults.data(forKey: favKey),
              let list = try? JSONDecoder().decode([FavoriteRoute].self, from: data),
              !list.isEmpty else {
            return [FavoriteRoute(from: "吉川橋", to: "越谷駅東口", dir: "")]
        }
        return list
    }

    func saveFavorites(_ routes: [FavoriteRoute]) {
        if let data = try? JSONEncoder().encode(routes) {
            defaults.set(data, forKey: favKey)
        }
    }

    func addFavorite(_ route: FavoriteRoute) {
        var list = loadFavorites()
        if !list.contains(route) {
            list.append(route)
            saveFavorites(list)
        }
    }

    func removeFavorite(at offsets: IndexSet) {
        var list = loadFavorites()
        for index in offsets.sorted(by: >) {
            if list.indices.contains(index) {
                list.remove(at: index)
            }
        }
        saveFavorites(list)
    }
}
