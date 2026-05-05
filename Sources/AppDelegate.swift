import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var tapEngine: TapEngine!
    var popover: NSPopover?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        tapEngine = TapEngine()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "TD"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        tapEngine.$isListening
            .receive(on: RunLoop.main)
            .sink { [weak self] isListening in
                self?.statusItem?.button?.title = isListening ? "TD*" : "TD"
            }
            .store(in: &cancellables)
    }

    @objc func togglePopover(_ sender: Any?) {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let p = NSPopover()
        p.contentSize = NSSize(width: 280, height: 400)
        p.behavior = .transient
        p.contentViewController = NSHostingController(rootView: MenuBarView(engine: tapEngine))
        if let button = statusItem.button {
            p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        self.popover = p
    }
}
