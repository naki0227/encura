// EnCura: "今日の一枚" on the Home Screen and the Lock Screen.
//
// The widget reads today's artwork straight from Supabase (the same public
// REST endpoint and key the app uses), so it stays current even when the app
// has not been opened. The URL and key are written into this extension's
// Info.plist at build time from the app's --dart-define values; nothing is
// stored in the repository.

import SwiftUI
import UIKit
import WidgetKit

// MARK: - Data

struct ArtEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let image: UIImage?

    static let sample = ArtEntry(date: Date(), title: "神奈川沖浪裏", artist: "葛飾北斎", image: nil)
    static let unavailable = ArtEntry(date: Date(), title: "アプリを開いて今日の一枚を見る", artist: "EnCura", image: nil)
}

private struct DailyColumn: Decodable {
    let title: String
    let artist: String
    let image_url: String
}

enum ArtLoader {
    private static let jst = TimeZone(identifier: "Asia/Tokyo")!

    private static var config: (url: String, key: String)? {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let url = info["EnCuraSupabaseURL"] as? String, !url.isEmpty,
              let key = info["EnCuraSupabaseKey"] as? String, !key.isEmpty else { return nil }
        return (url.hasSuffix("/") ? String(url.dropLast()) : url, key)
    }

    static func todayInJapan(_ now: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = jst
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }

    /// A few minutes after the next midnight in Japan, when a new work is up.
    static func nextRefresh(after now: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = jst
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        return tomorrow.addingTimeInterval(5 * 60)
    }

    private static func fetch(_ request: URLRequest) async -> (data: Data, response: URLResponse)? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return (data, response)
        } catch {
            return nil
        }
    }

    /// Today's work, or the latest one before today.
    static func load() async -> ArtEntry? {
        guard let config else { return nil }
        var components = URLComponents(string: "\(config.url)/rest/v1/daily_columns")
        components?.queryItems = [
            URLQueryItem(name: "select", value: "title,artist,image_url"),
            URLQueryItem(name: "display_date", value: "lte.\(todayInJapan())"),
            URLQueryItem(name: "order", value: "display_date.desc"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        guard let reply = await fetch(request),
              (reply.response as? HTTPURLResponse)?.statusCode == 200,
              let column = (try? JSONDecoder().decode([DailyColumn].self, from: reply.data))?.first else { return nil }
        return ArtEntry(date: Date(), title: column.title, artist: column.artist, image: await image(column.image_url))
    }

    /// Widgets have little memory: ask Wikimedia for a 500px thumbnail and
    /// scale it down further before keeping it.
    private static func image(_ raw: String) async -> UIImage? {
        let small = raw.replacingOccurrences(
            of: #"/\d+px-"#, with: "/500px-", options: .regularExpression)
        guard let url = URL(string: small) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("EnCura/widget (+https://enludus.com; contact@enludus.com)", forHTTPHeaderField: "User-Agent")
        guard let reply = await fetch(request),
              (reply.response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: reply.data) else { return nil }
        let side: CGFloat = 600
        let scale = min(1, side / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ArtEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (ArtEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task { completion(await ArtLoader.load() ?? .sample) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArtEntry>) -> Void) {
        Task {
            let entry = await ArtLoader.load()
            // Try again in an hour if the network or the server let us down.
            let next = entry == nil ? Date().addingTimeInterval(60 * 60) : ArtLoader.nextRefresh()
            completion(Timeline(entries: [entry ?? .unavailable], policy: .after(next)))
        }
    }
}

// MARK: - Views

private let room = Color(red: 0x0E / 255, green: 0x0F / 255, blue: 0x0E / 255)
private let gold = Color(red: 0xC5 / 255, green: 0xA0 / 255, blue: 0x59 / 255)

private struct TodayTag: View {
    var body: some View {
        Text("今日の一枚")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(room)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white)
    }
}

private struct ArtImage: View {
    let entry: ArtEntry
    var body: some View {
        if let image = entry.image {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            room
        }
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ArtEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("今日の一枚：\(entry.title)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("今日の一枚").font(.caption2).widgetAccentable()
                Text(entry.title).font(.headline).lineLimit(1)
                Text(entry.artist).font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetBackground(Color.clear)
        case .systemMedium:
            HStack(spacing: 12) {
                ArtImage(entry: entry)
                    .frame(width: 120)
                    .clipped()
                VStack(alignment: .leading, spacing: 6) {
                    TodayTag()
                    Text(entry.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)
                    Text(entry.artist)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.6))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .widgetBackground(room)
        default:
            // Small and large: the work fills the widget, the title sits on it.
            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)
                TodayTag()
                Text(entry.title)
                    .font(.system(size: family == .systemLarge ? 20 : 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                if family == .systemLarge {
                    Text(entry.artist)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.85))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .widgetBackground(
                ZStack {
                    ArtImage(entry: entry)
                    LinearGradient(
                        colors: [.clear, .clear, Color.black.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom)
                }
            )
        }
    }
}

extension View {
    /// iOS 17 draws the widget background edge to edge with containerBackground;
    /// earlier versions take a plain background.
    @ViewBuilder
    func widgetBackground<Background: View>(_ background: Background) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { background }
        } else {
            self.background(background)
        }
    }
}

@main
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayArt", provider: Provider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("今日の一枚")
        .description("EnCura の今日の一枚を、ホーム画面とロック画面に。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}
