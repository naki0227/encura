import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), title: "StudyReel", message: "Placeholder")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), title: "StudyReel", message: "Snapshot")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.example.encura")
        let title = userDefaults?.string(forKey: "title") ?? "StudyReel"
        let message = userDefaults?.string(forKey: "message") ?? "No Data"
        
        let entry = SimpleEntry(date: Date(), title: title, message: message)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let title: String
    let message: String
}

struct StudyReelWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack {
            Text(entry.title)
                .font(.headline)
            Text(entry.message)
                .font(.subheadline)
        }
    }
}

@main
struct StudyReelWidget: Widget {
    let kind: String = "StudyReelWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StudyReelWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("StudyReel Widget")
        .description("Displays your study status.")
    }
}
