import WidgetKit
import SwiftUI

// 1. Datan för varje tidslinjepunkt
struct SimpleEntry: TimelineEntry {
    let date: Date
}

// 2. Tidslinjestyrning
struct Provider: TimelineProvider {
    // Definiera explicit vilken Entry-typ som används
    typealias Entry = SimpleEntry

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}
// 3. SwiftUI-vy anpassad efter klockans komplikationsstorlek
struct RemoteEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: SimpleEntry
    
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: "sail-boat")
                    .font(.title2)
                
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Båt Remote")
                        .font(.headline)
                    Text("Senast uppd: \(entry.date, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
            case .accessoryInline:
                Text("Båt: \(entry.date, style: .time)")
                
            case .accessoryCorner:
                Image(systemName: "sail-boat")
                    .widgetLabel {
                        Text("OK")
                    }
                
            default:
                Text("Båt Remote")
            }
        } // <-- Slut på Group
        .containerBackground(.clear, for: .widget) // <-- Ska ligga HÄR, innan body stängs!
    } // <-- Slut på body
}
// 4. Själva Widget-konfigurationen
struct Remote: Widget {
    let kind: String = "Remote"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RemoteEntryView(entry: entry) // <-- Namnet ska matcha structen ovan
        }
        .configurationDisplayName("Båtstyrning")
        .description("Visa båtstatus direkt på urtavlan.")
        .supportedFamilies([
            .accessoryCircular,     // Rund liten ikon/text
            .accessoryRectangular,  // Rektangulär ruta med mer info
            .accessoryInline,       // Enkel rad text ovanför klockan
            .accessoryCorner        // Hörnkomplikationer
        ])
    }
}

// 5. Xcode Preview
#Preview(as: .accessoryRectangular) {
    Remote()
} timeline: {
    SimpleEntry(date: .now)
}
