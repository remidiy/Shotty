import SwiftUI

@main
struct ShottyApp: App {
    @State private var model = AppModel()

    init() {
        // `Shotty --fly <image> <bundle-id>`: play the fly-in animation once (for checking it by eye).
        if let i = CommandLine.arguments.firstIndex(of: "--fly"), i + 2 < CommandLine.arguments.count {
            let file = URL(fileURLWithPath: CommandLine.arguments[i + 1])
            let bundle = CommandLine.arguments[i + 2]
            DispatchQueue.main.async {
                FlyInAnimation.play(file: file, origin: .capture, targetBundleID: bundle)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { NSApp.terminate(nil) }
            }
        }
        if DemoWindow.isActive {
            let model = _model.wrappedValue
            DispatchQueue.main.async { DemoWindow.show(model: model) }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            // Placeholder glyph until the final logo is ready.
            Image(systemName: model.enabled ? "camera.viewfinder" : "pause.circle")
                .accessibilityLabel("Shotty")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
