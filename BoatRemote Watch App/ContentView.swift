import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: AutopilotService
    @State private var showingSettings = false

    // Hjälpfunktion för vibration/haptik
    private func triggerHaptic(_ type: WKHapticType = .click) {
        WKInterfaceDevice.current().play(type)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                
                // MARK: - Standby / Auto
                HStack(spacing: 6) {
                    Button(action: {
                        triggerHaptic(.directionUp)
                        service.setState("standby")
                    }) {
                        Text("STBY")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .tint(.red)

                    Button(action: {
                        triggerHaptic(.directionDown)
                        service.setState("auto")
                    }) {
                        Text("AUTO")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .tint(.green)
                }
                .frame(height: 48)

                // MARK: - Kursjustering (-1°/+1° vid tryck, -10°/+10° vid långtryck)
                HStack(spacing: 6) {
                    // Babord (-1° / -10°)
                    Button(action: {
                        triggerHaptic(.click)
                        service.adjustHeading(-1)
                    }) {
                        VStack(spacing: 0) {
                            Text("-1°")
                                .font(.title2.bold())
                            Text("Håll -10°")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            triggerHaptic(.retry) // Annan känsla vid 10°
                            service.adjustHeading(-10)
                        }
                    )

                    // Styrbord (+1° / +10°)
                    Button(action: {
                        triggerHaptic(.click)
                        service.adjustHeading(1)
                    }) {
                        VStack(spacing: 0) {
                            Text("+1°")
                                .font(.title2.bold())
                            Text("Håll +10°")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            triggerHaptic(.retry)
                            service.adjustHeading(10)
                        }
                    )
                }
                .frame(height: 50)

                // MARK: - Slag / Tack
                HStack(spacing: 6) {
                    Button(action: {
                        triggerHaptic(.notification)
                        service.tack("port")
                    }) {
                        Image(systemName: "arrow.turn.up.left")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .tint(.orange)

                    Button(action: {
                        triggerHaptic(.notification)
                        service.tack("starboard")
                    }) {
                        Image(systemName: "arrow.turn.up.right")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .tint(.orange)
                }
                .frame(height: 48)

                // MARK: - Status & Inställningar
                HStack {
                    Text(service.lastStatus)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
            // MARK: - AWA i överkanten till vänster om klockan
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 3) {
                        Image(systemName: "wind")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.cyan)
                        
                        Text("AWA \(service.awa ?? 0)°")
                            .font(.system(size: 18, weight: .bold))
                            .monospacedDigit()
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}
