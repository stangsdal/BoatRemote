import WidgetKit
import SwiftUI

// 1. Datan för varje tidslinjepunkt
struct SimpleEntry: TimelineEntry {
    let date: Date
}

// 2. Tidslinjestyrning
struct Provider: TimelineProvider {
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
                Image(systemName: "sailing.fill")
                    .font(.title2)
                
            case .accessoryRectangular:
                // Snygg Knapp-design
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FIDELI REMOTE")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.blue)
                        Text("Tryck för styrning")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Visuell knapp/ikon med rund tonad bakgrund
                    Image(systemName: "power")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(.blue.gradient))
                }
                
            case .accessoryInline:
                Text("Båt: \(entry.date, style: .time)")
                
            case .accessoryCorner:
                Image(systemName: "sailing.fill")
                    .widgetLabel {
                        Text("OK")
                    }
                
            default:
                Text("Båt Remote")
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

// 4. Själva Widget-konfigurationen
struct Remote: Widget {
    let kind: String = "Remote"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RemoteEntryView(entry: entry)
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
