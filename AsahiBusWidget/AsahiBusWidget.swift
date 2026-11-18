import WidgetKit
import SwiftUI

struct BusEntry: TimelineEntry {
    let date: Date
    let primaryData: BusAPIResponse?
    let secondaryData: BusAPIResponse?
}

struct BusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BusEntry {
        BusEntry(date: Date(), primaryData: nil, secondaryData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BusEntry) -> Void) {
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BusEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 3, to: Date()) ?? Date().addingTimeInterval(180)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func fetchEntry() async -> BusEntry {
        let favs = RouteStore.shared.loadFavorites()
        var first: BusAPIResponse?
        var second: BusAPIResponse?

        if let f1 = favs.first {
            first = try? await BusAPIClient.shared.fetchBus(from: f1.from, to: f1.to, dir: f1.dir)
        }
        if favs.count > 1 {
            let f2 = favs[1]
            second = try? await BusAPIClient.shared.fetchBus(from: f2.from, to: f2.to, dir: f2.dir)
        }
        return BusEntry(date: Date(), primaryData: first, secondaryData: second)
    }
}

struct AsahiBusWidgetEntryView: View {
    var entry: BusEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 17.0, *) {
            widgetContent
                .containerBackground(Color.black, for: .widget)
        } else {
            widgetContent
                .background(Color.black)
        }
    }

    @ViewBuilder
    private var widgetContent: some View {
        if let data = entry.primaryData {
            if family == .systemSmall {
                smallView(data: data)
            } else {
                mediumView(first: data, second: entry.secondaryData)
            }
        } else {
            Text("朝日バスナビ\n読み込み中")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func smallView(data: BusAPIResponse) -> some View {
        let bus = data.buses.first ?? data.nextBus
        return VStack(alignment: .leading, spacing: 4) {
            Text(data.stopName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(bus.isLive ? "朝日バスナビ" : "時刻表")
                .font(.system(size: 9, weight: .heavy))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(bus.isLive ? Color.blue.opacity(0.3) : Color.white.opacity(0.12))
                .foregroundColor(bus.isLive ? .blue : .gray)
                .cornerRadius(4)

            Spacer()

            Text(bus.predictedTime)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(bus.isDelayed ? .orange : .white)

            Text(bus.stopsAwayText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(bus.isLive ? .indigo : .gray)
                .lineLimit(1)
        }
        .padding(12)
    }

    private func mediumView(first: BusAPIResponse, second: BusAPIResponse?) -> some View {
        HStack(spacing: 10) {
            routeColumn(data: first)
            if let second {
                Divider().background(Color.gray.opacity(0.3))
                routeColumn(data: second)
            }
        }
        .padding(12)
    }

    private func routeColumn(data: BusAPIResponse) -> some View {
        let bus = data.buses.first ?? data.nextBus
        return VStack(alignment: .leading, spacing: 4) {
            Text(data.stopName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(bus.isLive ? "朝日バスナビから取得" : "時刻表から取得")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(bus.isLive ? .blue : .gray)

            Text(bus.predictedTime)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(bus.isDelayed ? .orange : .white)

            Text(bus.stopsAwayText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@main
struct AsahiBusWidget: Widget {
    let kind: String = "AsahiBusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BusTimelineProvider()) { entry in
            AsahiBusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("朝日バスナビ")
        .description("登録したバス停のリアルタイム接近予測を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
