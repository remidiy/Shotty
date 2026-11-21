import SwiftUI

@main
struct ShottyApp: App {
    @State private var model = AppModel()

    init() {
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
