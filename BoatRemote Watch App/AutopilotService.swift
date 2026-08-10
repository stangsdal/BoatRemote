//
//  AutopilotService.swift
//  BoatRemote
//
//  Created by Philip Werner on 2026-07-29.
//

import Foundation
import Combine

/// Håller koll på anslutningsinställningar (IP/host + token), hanterar
/// realtidsdata (AWA/AWS) via WebSocket (med HTTP-polling fallback) samt
/// alla anrop mot Signal K autopilot-API:et.
final class AutopilotService: ObservableObject {

    // MARK: - Inställningar (sparas i UserDefaults)

    @Published var serverHost: String {
        didSet {
            let cleaned = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(cleaned, forKey: "sk_host")
            reconnectWebSocket()
        }
    }
    @Published var token: String {
        didSet {
            let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(cleaned, forKey: "sk_token")
            reconnectWebSocket()
        }
    }

    /// Senaste status-text, visas längst ner i UI:t.
    @Published var lastStatus: String = "Redo"
    
    // MARK: - Realtidsdata
    @Published var awa: Int? = nil        // Apparent Wind Angle (i grader, 0-180)
    @Published var aws: Double? = nil     // Apparent Wind Speed (i knop)

    // MARK: - Nätverk & Timers
    private var webSocketTask: URLSessionWebSocketTask?
    private var isWebSocketActive = false
    private var pollingTimer: Timer?

    init() {
        self.serverHost = UserDefaults.standard.string(forKey: "sk_host") ?? "192.168.1.100:3000"
        self.token = UserDefaults.standard.string(forKey: "sk_token") ?? ""
        
        connectWebSocket()
        startPollingFallback()
    }

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        pollingTimer?.invalidate()
    }

    private var hostWithScheme: String {
        let trimmed = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "http://\(trimmed)"
    }

    private var wsURLString: String {
        let trimmed = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
        var host = trimmed
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        
        if host.hasSuffix("/") {
            host.removeLast()
        }
        
        var urlStr = "ws://\(host)/signalk/v1/stream?subscribe=self"
        if !token.isEmpty {
            urlStr += "&token=\(token)"
        }
        return urlStr
    }

    private var baseURL: String {
        "\(hostWithScheme)/signalk/v1/api/vessels/self/steering/autopilot"
    }

    // MARK: - WebSocket Implementation

    private func reconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isWebSocketActive = false
        connectWebSocket()
    }

    private func connectWebSocket() {
        guard let url = URL(string: wsURLString) else { return }
        
        var request = URLRequest(url: url)
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        isWebSocketActive = true
        listenWebSocket()
    }

    private func listenWebSocket() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.parseSignalKDelta(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.parseSignalKDelta(text)
                    }
                @unknown default:
                    break
                }
                self.listenWebSocket()
                
            case .failure(let error):
                print("WebSocket fel: \(error.localizedDescription)")
                self.isWebSocketActive = false
                
                // Försök återansluta om 5 sekunder
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.connectWebSocket()
                }
            }
        }
    }

    private func parseSignalKDelta(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let updates = json["updates"] as? [[String: Any]] else { return }

        for update in updates {
            guard let values = update["values"] as? [[String: Any]] else { continue }
            for item in values {
                guard let path = item["path"] as? String,
                      let rawVal = item["value"] as? Double else { continue }

                if path == "environment.wind.angleApparent" {
                    // Exakt samma beräkning som i din iPad-kod
                    let degrees = abs((rawVal * 180.0) / .pi)
                    let boundedAWA = Int(min(degrees, 180.0))
                    
                    DispatchQueue.main.async {
                        self.awa = boundedAWA
                    }
                } else if path == "environment.wind.speedApparent" {
                    let knots = rawVal * 1.94384
                    DispatchQueue.main.async {
                        self.aws = knots
                    }
                }
            }
        }
    }

    // MARK: - Polling Fallback (körs om WebSocket skulle tappa anslutningen)

    private func startPollingFallback() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isWebSocketActive else { return }
            self.fetchWindDataViaREST()
        }
    }

    private func fetchWindDataViaREST() {
        let apiBase = "\(hostWithScheme)/signalk/v1/api/vessels/self/environment/wind"
        
        // 1. Fetch AWA
        if let awaURL = URL(string: "\(apiBase)/angleApparent") {
            var req = URLRequest(url: awaURL)
            if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
                guard let self = self, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let radVal = json["value"] as? Double else { return }
                
                let degrees = abs((radVal * 180.0) / .pi)
                let boundedAWA = Int(min(degrees, 180.0))
                
                DispatchQueue.main.async {
                    self.awa = boundedAWA
                }
            }.resume()
        }
        
        // 2. Fetch AWS
        if let awsURL = URL(string: "\(apiBase)/speedApparent") {
            var req = URLRequest(url: awsURL)
            if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
                guard let self = self, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let mpsVal = json["value"] as? Double else { return }
                
                let knots = mpsVal * 1.94384
                DispatchQueue.main.async {
                    self.aws = knots
                }
            }.resume()
        }
    }

    // MARK: - Publika kommandon

    func setState(_ value: String) {
        put(path: "/state", body: ["value": value], label: value.uppercased())
    }

    func adjustHeading(_ delta: Int) {
        put(path: "/actions/adjustHeading", body: ["value": delta], label: "JUSTERA \(delta > 0 ? "+\(delta)" : "\(delta)")")
    }

    func tack(_ side: String) {
        put(path: "/actions/tack", body: ["value": side], label: "TACK \(side.uppercased())")
    }

    // MARK: - Signal K Access Flow

    func requestAccess() {
        guard let url = URL(string: "\(hostWithScheme)/signalk/v1/access/requests") else {
            DispatchQueue.main.async { self.lastStatus = "Ogiltig server-adress" }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "clientId": "se.philip.BoatRemote.watch",
            "description": "BoatRemote Apple Watch"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        DispatchQueue.main.async { self.lastStatus = "Begär access..." }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.lastStatus = "Fel: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let href = json["href"] as? String else {
                DispatchQueue.main.async {
                    self.lastStatus = "Ingen href i svaret"
                }
                return
            }
            
            DispatchQueue.main.async {
                self.lastStatus = "Godkänn i Signal K-webben..."
            }
            
            // Starta polling med en räknare (max 30 försök = 60 sek)
            self.pollAccessRequest(href: href, remainingAttempts: 30)
        }.resume()
    }
    
    private func pollAccessRequest(href: String, remainingAttempts: Int = 30) {
        guard remainingAttempts > 0 else {
            DispatchQueue.main.async {
                self.lastStatus = "Timeout: Ej godkänd i tid"
            }
            return
        }
        
        let urlString = href.hasPrefix("http") ? href : "\(hostWithScheme)\(href)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let state = json["state"] as? String else { return }
                
            // Signal K kan svara med antingen APPROVED eller COMPLETED
            if state == "APPROVED" || state == "COMPLETED" {
                
                // Leta efter token på alla ställen Signal K brukar stoppa den:
                let foundToken = json["token"] as? String
                    ?? (json["accessRequest"] as? [String: Any])?["token"] as? String
                    ?? (json["result"] as? [String: Any])?["token"] as? String

                if let validToken = foundToken {
                    DispatchQueue.main.async {
                        self.token = validToken
                        self.lastStatus = "Token sparad!"
                        print("Ny token sparades i UserDefaults")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.lastStatus = "Godkänd, men saknar token"
                    }
                }
                
            } else if state == "PENDING" {
                // Fortsätt polla varannan sekund
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.pollAccessRequest(href: href, remainingAttempts: remainingAttempts - 1)
                }
            } else {
                DispatchQueue.main.async {
                    self.lastStatus = "Ansökan \(state.lowercased())"
                }
            }
        }.resume()
    }

    // MARK: - Generellt PUT-anrop

    private func put(path: String, body: [String: Any], label: String) {
        guard let url = URL(string: baseURL + path) else {
            DispatchQueue.main.async { self.lastStatus = "Ogiltig URL" }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.lastStatus = "\(label): Fel"
                    print("Nätverksfel: \(error.localizedDescription)")
                    return
                }
                
                if let http = response as? HTTPURLResponse {
                    if (200...299).contains(http.statusCode) {
                        self.lastStatus = "\(label): OK"
                    } else if http.statusCode == 401 || http.statusCode == 403 {
                        self.lastStatus = "\(label): Saknar behörighet"
                    } else {
                        self.lastStatus = "\(label): HTTP \(http.statusCode)"
                    }
                } else {
                    self.lastStatus = "\(label): Okänt svar"
                }
            }
        }.resume()
    }
}
