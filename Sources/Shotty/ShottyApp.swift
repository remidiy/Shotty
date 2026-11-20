import SwiftUI

@main
struct ShottyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image(active: model.enabled))
                .accessibilityLabel("Shotty")
        }
        .menuBarExtraStyle(.window)
    }
}
