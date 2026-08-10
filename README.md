# BoatRemote Watch App - AutopilotService

`AutopilotService` är kärnan i watchOS-appen **BoatRemote**. Den hanterar kommunikation, status och styrning mot [Signal K](https://signalk.org/)-servern ombord på båten (Fideli).

---

## 🌟 Huvudfunktioner

* **Realtidsdata via WebSocket:** Ansluter till Signal K Stream (`ws://`) för kontinuerlig uppdatering av skenbar vindvinkel (AWA) och skenbar vindhastighet (AWS).
* **Exponential Backoff:** Om WebSocket kopplas från ökar återanslutningsintervallet gradvis (från 5s upp till 60s) för att undvika batteridränering.
* **REST Fallback (Polling):** Om WebSocket inte är aktiv faller appen tillbaka på regelbundna HTTP REST-anrop för att hämta vinddata.
* **Circuit Breaker / Offline-hantering:**
  * Anpassad `URLSession` med 2,0 sekunders aggressiv timeout.
  * Upptäcker om båtens Wi-Fi saknas (`192.168.1.100` onåbar).
  * Pausar tät polling och korta anrop omgående för att stoppa konsolbrus (timeouts/NECP policy-fel) och spara klockans batteri när du inte är på båten.
  * Kör tysta kontrollförsök var 30:e sekund för att automatiskt återansluta när du kliver ombord.
* **Signal K Access Flow:** Inbyggd mekanism för att begära och poll-vänta på en godkänd access-token direkt i Signal K.

---

## 🏗 Systemarkitektur
```text
┌──────────────────────────────────────────────────────────┐
│                   BoatRemote Watch App                   │
│                                                          │
│   ┌──────────────────────────────────────────────────┐   │
│   │                 AutopilotService                 │   │
│   └──────────┬────────────────────────────┬──────────┘   │
└──────────────┼────────────────────────────┼──────────────┘
│                            │
WebSocket (ws://)               REST HTTP (http://)
(Vinddata AWA/AWS)              (Kommandon / Fallback)
│                            │
▼                            ▼
┌──────────────────────────────────────────────────────────┐
│                  Signal K Server (Båt)                   │
│                    192.168.1.100:3000                    │
└──────────────────────────────────────────────────────────┘


---

## 📋 Xcode & Projektkonfiguration (`Info.plist`)

För att watchOS ska tillåta lokal nätverkskommunikation och okrypterade HTTP/WS-anslutningar krävs följande i klockappens `Info.plist`:

```xml
<!-- Tillåt sökning och kommunikation på lokala båtnätverket -->
<key>NSLocalNetworkUsageDescription</key>
<string>Appen behöver ansluta till Signal K på båtens lokala nätverk.</string>

<!-- App Transport Security (ATS) för lokal HTTP/WS -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
⚙️ Inställningar & Användning
Parametrar i UserDefaults:
serverHost: IP-adress och port till Signal K (Standard: 192.168.1.100:3000).
token: JWT-token för auktorisering mot Signal K API.
Exempel på användning i SwiftUI Views:
Swift
struct ContentView: View {
    @StateObject private var autopilot = AutopilotService()

    var body: some View {
        VStack(spacing: 8) {
            if let awa = autopilot.awa {
                Text("AWA: \(awa)°")
                    .font(.title)
            } else {
                Text("AWA: --")
            }

            HStack {
                Button("-10") { autopilot.adjustHeading(-10) }
                Button("+10") { autopilot.adjustHeading(10) }
            }

            Text(autopilot.lastStatus)
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
}
📡 Signal K Endpoints som används:

| Typ | Sökväg / Path | Beskrivning |
| --- | --- | --- |
| **WS** | `/signalk/v1/stream?subscribe=self` | WebSocket-ström för `environment.wind.*` |
| **GET** | `/signalk/v1/api/vessels/self/environment/wind/angleApparent` | Hämta vindvinkel via REST |
| **POST** | `/signalk/v1/access/requests` | Begär ny access-token från Signal K |
| **PUT** | `/signalk/v1/api/vessels/self/steering/autopilot/state` | Ändra läge (Auto, Standby, Wind, etc.) |
| **PUT** | `/signalk/v1/api/vessels/self/steering/autopilot/actions/adjustHeading` | Justera kurs (t.ex. `+1`, `-10`) |
| **PUT** | `/signalk/v1/api/vessels/self/steering/autopilot/actions/tack` | Slå (port/starboard) |

