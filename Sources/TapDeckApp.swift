import SwiftUI

@main
struct TapDeckApp: App {
    @StateObject private var tapEngine = TapEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(engine: tapEngine)
        } label: {
            Image(systemName: tapEngine.isListening ? "hand.tap.fill" : "hand.tap")
        }
        .menuBarExtraStyle(.window)
    }
}
