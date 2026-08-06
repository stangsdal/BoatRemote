//
//  BoatRemoteApp.swift
//  BoatRemote Watch App
//
//  Created by Philip Werner on 2026-07-29.
//
import SwiftUI

@main
struct BoatRemote_Watch_AppApp: App {
    @StateObject private var service = AutopilotService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
        }
    }
}
