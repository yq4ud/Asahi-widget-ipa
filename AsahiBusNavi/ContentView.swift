import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var favorites: [FavoriteRoute] = RouteStore.shared.loadFavorites()
    @State private var results: [String: BusAPIResponse] = [:]
    @State private var isLoading = false
    @State private var lastFetched = Date()
    @State private var now = Date()

    @State private var isSearchOpen = false
    @State private var searchFrom = ""
    @State private var searchTo = ""
    @State private var searchResult: BusAPIResponse?
    @State private var isSearching = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerBar

                    if isSearchOpen {
                        searchPanel
                    }

                    ForEach(Array(favorites.enumerated()), id: \.element.id) { index, fav in
                        if let data = results[fav.id] {
                            RouteCardView(
                                data: data,
                                now: now,
                                actionTitle: "削除",
                                actionIsDestructive: true,
                                onAction: {
                                    RouteStore.shared.removeFavorite(at: IndexSet(integer: index))
                                    favorites = RouteStore.shared.loadFavorites()
                                    WidgetCenter.shared.reloadAllTimelines()
                                }
                            )
                        } else {
                            ProgressCardView(title: "\(fav.from) を取得中...")
                        }
                    }

                    Text("made by yq4uz")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .task {
            await reloadAll()
        }
        .onReceive(timer) { input in
            now = input
        }
    }

    private var headerBar: some View {
        HStack {
            Text("朝日バスナビ")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            let elapsedMin = Int(now.timeIntervalSince(lastFetched) / 60)
            Text(elapsedMin < 1 ? "たった今更新" : "⚠️ \(elapsedMin)分前の情報")
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(elapsedMin < 1 ? Color.green.opacity(0.18) : Color.red.opacity(0.2))
                .foregroundColor(elapsedMin < 1 ? .green : .red)
                .clipShape(Capsule())

            Button {
                Task { await reloadAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Circle())
            }

            Button {
                withAnimation { isSearchOpen.toggle() }
            } label: {
                Text(isSearchOpen ? "× 閉じる" : "＋ 追加")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 8)
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("乗るバス停（必須）")
                .font(.caption)
                .foregroundColor(.gray)
            TextField("例：吉川橋、越谷駅東口", text: $searchFrom)
                .textFieldStyle(.roundedBorder)

            Text("降りるバス停（空欄でもOK）")
                .font(.caption)
                .foregroundColor(.gray)
            TextField("例：越谷駅東口", text: $searchTo)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await performSearch(dir: "") }
            } label: {
                Text(isSearching ? "取得中..." : "このバス停を調べる")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(searchFrom.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)

            if let sr = searchResult {
                if sr.directions.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(sr.directions, id: \.self) { dir in
                                Button {
                                    Task { await performSearch(dir: dir) }
                                } label: {
                                    Text(dir)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(dir == sr.selectedDir ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }

                RouteCardView(
                    data: sr,
                    now: now,
                    actionTitle: "＋ 保存",
                    actionIsDestructive: false,
                    onAction: {
                        let newRoute = FavoriteRoute(
                            from: searchFrom.trimmingCharacters(in: .whitespaces),
                            to: searchTo.trimmingCharacters(in: .whitespaces),
                            dir: sr.selectedDir
                        )
                        RouteStore.shared.addFavorite(newRoute)
                        favorites = RouteStore.shared.loadFavorites()
                        searchResult = nil
                        isSearchOpen = false
                        WidgetCenter.shared.reloadAllTimelines()
                        Task { await reloadAll() }
                    }
                )
            }
        }
        .padding(14)
        .background(Color(white: 0.11))
        .cornerRadius(16)
    }

    private func reloadAll() async {
        isLoading = true
        for fav in favorites {
            if let res = try? await BusAPIClient.shared.fetchBus(from: fav.from, to: fav.to, dir: fav.dir) {
                results[fav.id] = res
            }
        }
        lastFetched = Date()
        isLoading = false
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func performSearch(dir: String) async {
        let f = searchFrom.trimmingCharacters(in: .whitespaces)
        let t = searchTo.trimmingCharacters(in: .whitespaces)
        guard !f.isEmpty else { return }
        isSearching = true
        searchResult = try? await BusAPIClient.shared.fetchBus(from: f, to: t, dir: dir)
        isSearching = false
    }
}

struct RouteCardView: View {
    let data: BusAPIResponse
    let now: Date
    let actionTitle: String
    let actionIsDestructive: Bool
    let onAction: () -> Void

    @State private var showMore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(data.stopName)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(actionIsDestructive ? Color.red.opacity(0.18) : Color.blue)
                        .foregroundColor(actionIsDestructive ? .red : .white)
                        .clipShape(Capsule())
                }
            }

            let primary = data.buses.first ?? data.nextBus
            PrimarySlotView(bus: primary, data: data, now: now)

            if data.buses.count > 1 {
                if showMore {
                    ForEach(Array(data.buses.dropFirst().enumerated()), id: \.offset) { idx, bus in
                        SecondarySlotView(order: idx + 2, bus: bus, data: data, now: now)
                    }
                }

                Button {
                    withAnimation { showMore.toggle() }
                } label: {
                    Text(showMore ? "▲ 閉じる" : "▼ もう少し後を見る（あと\(data.buses.count - 1)本）")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.15))
                        .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.11))
        .cornerRadius(18)
    }
}

struct PrimarySlotView: View {
    let bus: BusItem
    let data: BusAPIResponse
    let now: Date

    var body: some View {
        let linkStr = bus.isLive ? data.naviUrl : (data.timetableUrl ?? data.detailUrl)
        let content = VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bus.isLive ? "🚌 朝日バスナビから取得" : "📅 時刻表から取得")
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(bus.isLive ? Color.blue.opacity(0.25) : Color.white.opacity(0.1))
                    .foregroundColor(bus.isLive ? Color(red: 0.4, green: 0.72, blue: 1.0) : .gray)
                    .cornerRadius(6)

                Spacer()

                Text(bus.stopsAwayText)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(bus.isLive ? Color.indigo.opacity(0.38) : Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            HStack(alignment: .bottom) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bus.isLive ? "予測時刻" : "定刻ダイヤ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        Text(bus.predictedTime)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(bus.isDelayed ? .orange : .white)
                    }

                    if bus.isLive {
                        if bus.isDelayed {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("予定 \(bus.scheduledTime)")
                                    .font(.caption2)
                                    .strikethrough()
                                    .foregroundColor(.gray)
                                Text("+\(bus.delayMinutes)分遅れ")
                                    .font(.system(size: 11, weight: .heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundColor(.black)
                                    .cornerRadius(5)
                            }
                        } else {
                            Text("● 定刻通り")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                if let target = bus.targetDate(now: now) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("あと")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(formatCountdown(to: target, from: now))
                            .font(.system(size: 17, weight: .black))
                            .foregroundColor(.red)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(12)
        .background(bus.isDelayed ? Color.orange.opacity(0.15) : (bus.isLive ? Color.blue.opacity(0.15) : Color(white: 0.15)))
        .cornerRadius(14)

        if let url = URL(string: linkStr) {
            Link(destination: url) { content }
        } else {
            content
        }
    }
}

struct SecondarySlotView: View {
    let order: Int
    let bus: BusItem
    let data: BusAPIResponse
    let now: Date

    var body: some View {
        let linkStr = bus.isLive ? data.naviUrl : (data.timetableUrl ?? data.detailUrl)
        let row = HStack {
            Text(order == 2 ? "次の便" : "\(order)本目")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(bus.isLive ? Color.blue.opacity(0.22) : Color.white.opacity(0.08))
                .foregroundColor(bus.isLive ? .blue : .gray)
                .cornerRadius(4)

            Text(bus.predictedTime)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(bus.isDelayed ? .orange : .white)

            Text(bus.isLive ? "朝日バスナビ (\(bus.stopsAwayText))" : "時刻表から取得")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(bus.isLive ? Color(red: 0.4, green: 0.72, blue: 1.0) : .gray)
                .lineLimit(1)

            Spacer()

            if let target = bus.targetDate(now: now) {
                Text(formatCountdown(to: target, from: now))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(white: 0.14))
        .cornerRadius(10)

        if let url = URL(string: linkStr) {
            Link(destination: url) { row }
        } else {
            row
        }
    }
}

struct ProgressCardView: View {
    let title: String
    var body: some View {
        HStack {
            ProgressView()
            Text(title).font(.subheadline).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(white: 0.11))
        .cornerRadius(16)
    }
}

func formatCountdown(to target: Date, from now: Date) -> String {
    let diff = Int(target.timeIntervalSince(now))
    if diff <= 0 { return "まもなく" }
    if diff >= 3600 {
        return "\(diff / 3600)時間\((diff % 3600) / 60)分"
    }
    return String(format: "%d分%02d秒", diff / 60, diff % 60)
}
