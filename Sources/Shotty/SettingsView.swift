import SwiftUI

/// Standard macOS Settings window (⌘,), grouped form like System Settings.
struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Watching") {
                LabeledContent("Folder") {
                    HStack(spacing: 6) {
                        Text(model.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Choose…") { model.chooseFolder() }
                    }
                }
                if model.customFolderPath != nil {
                    Button("Use the macOS screenshot folder") { model.useSystemFolder() }
                }
                Toggle("Include screen recordings", isOn: $model.includeRecordings)
                Toggle("Only files macOS marks as screenshots", isOn: $model.onlyScreenshots)
            }

            Section {
                Toggle("Capture shortcut \(InstantCapture.shortcutLabel)", isOn: $model.hotKeyEnabled)
                LabeledContent("Floating thumbnail") {
                    if model.thumbnailSlowsCaptures {
                        Button("Turn Off for Instant Sends") { model.makeCapturesInstant() }
                    } else {
                        Text("Off, screenshots save instantly").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Speed")
            } footer: {
                Text("⇧⌘4 screenshots wait about 5 seconds while macOS shows its thumbnail. Shotty's own shortcut never waits. Captures from it are saved in ~/Pictures/Shotty.")
                    .foregroundStyle(.secondary)
            }

            Section("Sending") {
                Toggle("Send to the app I was using", isOn: $model.followFrontmost)
                if !model.followFrontmost {
                    Picker("Always send to", selection: $model.targetID) {
                        ForEach(model.availableTargets) { Text($0.name).tag($0.bundleID) }
                    }
                }
                Toggle("Send automatically (press Return)", isOn: $model.autoSend)
                Toggle("Restore my clipboard afterwards", isOn: $model.restoreClipboard)
            }

            Section("History") {
                LabeledContent("Saved captures") {
                    HStack {
                        Text("\(model.recent.count)").foregroundStyle(.secondary)
                        Button("Clear History") { model.clearHistory() }.disabled(model.recent.isEmpty)
                    }
                }
            }

            Section("General") {
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
                LabeledContent("Accessibility") {
                    if model.accessibilityGranted {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Allow…") { Sender.requestAccessibility() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
