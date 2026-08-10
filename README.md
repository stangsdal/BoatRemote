# BoatRemote Watch App - AutopilotService

`AutopilotService` är kärnan i watchOS-appen **BoatRemote**. Den hanterar kommunikation, status och styrning mot [Signal K](https://signalk.org/)-servern ombord på båten (Fideli).

---
## 📱 Skärmdumpar

<p align="center">
  <img src="https://github.com/user-attachments/assets/1ef09676-a406-468b-be74-f0f38cbd828b" width="220" alt="BoatRemote App i klockan" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/3cd5cad9-3ef6-4b67-94b0-a943105fb992" width="220" alt="BoatRemote Complication på urtavlan" />
</p>

<p align="center">
  <i>Vänster: Huvudvyn i klockan med vinddata och snabbkommandon. Höger: Direktåtkomst via Complication på urtavlan.</i>
</p>


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


---

## 🚀 Installation & Komma igång

Så här klonar du projektet till din Mac och installerar appen på din Apple Watch via Xcode.

### Steg 1: Ladda ner projektet från GitHub
Du behöver ladda ner kodbasen till din lokala utvecklingsmiljö.

**Alternativ A: Via Terminal (Rekommenderas)**
1. Öppna programmet **Terminal** på din Mac.
2. Navigera till den mapp där du vill spara projektet (t.ex. `cd ~/Documents`).
3. Kör följande kommando:
   ```bash
   git clone [https://github.com/nrjphwe/BoatRemote.git](https://github.com/nrjphwe/BoatRemote.git)
   
**Alternativ B: Ladda ner som ZIP
1. Gå till repositoryt på GitHub: nrjphwe/BoatRemote.
2. Klicka på den gröna knappen "Code" och välj "Download ZIP".
3. Packa upp ZIP-filen på din dator.

### Steg 2: Öppna projektet i Xcode
1. Se till att du har Xcode installerat via Mac App Store.
2. Öppna Xcode och klicka på "Open a project or file" (eller i menyn: File > Open...).
3. Leta upp den nedladdade BoatRemote-mappen och dubbelklicka på projektfilen: BoatRemote.xcodeproj.

### Steg 3: Signera appen med ditt Apple-ID
För att få köra appen på en fysisk klocka måste den vara kodsignerad med ett Apple-utvecklarkonto. Det räcker med ett gratis Apple-ID.
1. Klicka på huvudprojektet (det blå Xcode-ikonen) högst upp i filträdet till vänster.
2. I högerpanelen, välj fliken "Signing & Capabilities".
3.Under rubriken Team, klicka på rullgardinsmenyn.
 - Om ditt Apple-ID inte finns med, klicka på "Add an Account..." och logga in.
4.Välj ditt eget namn/team (t.ex. Philip Werner (Personal Team)).
5. Se till att rutan "Automatically manage signing" är ikryssad.
6.Kontrollera att din "Bundle Identifier" är unik (ex: se.philip.BoatRemote.watch).

### Steg 4: Installera på Apple Watch
Detta steg kräver att din Apple Watch och iPhone är anslutna eller att din klocka är ihopparad med din Mac för utveckling (Developer Mode).
1. Lås upp din iPhone och Apple Watch.
2. Anslut din iPhone till Macen med en kabel (eller se till att klockan och datorn är på samma nätverk).
3. Gå in i Inställningar > Integritet och säkerhet > Utvecklarläge på din Apple Watch och aktivera det. (Klockan kommer be om omstart).
4. Högst upp i Xcode-fönstret (i mitten) ser du en "Play"-knapp och bredvid den vilken enhet du bygger mot.
5. Klicka på enhetsnamnet och välj din fysiska Apple Watch i listan under iOS Device (ofta listad som ett underobjekt till din inkopplade iPhone).
6. Tryck på "Play"-knappen (eller Cmd + R) för att bygga (Build) och installera (Run) appen på klockan!

När byggnationen är klar (kan ta någon minut första gången) kommer appen automatiskt att öppnas på din handled.


⌚️ Vilka urtavlor (Watch Faces) passar bäst?
Eftersom watchOS erbjuder många olika typer av urtavlor och komplikationsplatser finns det tre källor/typer som passar extra bra för en båt-app som BoatRemote:

1. Modulär Kompakt & Modulär (Modular & Modular Compact)
Varför? Dessa har platser för stora/breda rektangulära komplikationer i mitten.
Passar för: Om din komplikation visar text eller två värden samtidigt (t.ex. både vindvinkel AWA: 45° och vindhastighet AWS: 12 kt).
bilden ovan är för Modular Compact.

2. Wayfinder & Ultra Modulär (För Apple Watch Ultra)
Varför? Speciellt framtagna för utomhusaktiviteter och navigation med hög kontrast och mycket utrymme i kanterna.
Passar för: Båtägare som vill ha snabb åtkomst till autopilot och vind i hörnkomplikationerna eller den stora mittenytan, samtidigt som kompassen är aktiv i mitten.
3. Infograf (Infograph)
Varför? Har upp till 8 komplikationer samtidigt (fyra i hörnen och fyra i mitten).
Passar för: När du vill ha en ren cirkulär ikon (Launcher) i ett av hörnen för att snabbt starta appen med ett tryck, samtidigt som du har andra instrument (som regn/vind-prognos eller tidur) på resten av urtavlan.
