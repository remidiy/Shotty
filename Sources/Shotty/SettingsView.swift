import SwiftUI

/// Standard macOS Settings window (⌘,), grouped form like System Settings.
struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        SettingsForm(model: model)
            .frame(width: 460)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The settings content, shared by the Settings window and the main window's Settings section.
struct SettingsForm: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

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
                Toggle("Animate captures into the app", isOn: $model.animateCaptures)
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
                Toggle("Eyes follow the pointer", isOn: $model.eyesFollowPointer)
                Button("Show Welcome Guide…") { openWindow(id: SceneID.welcome) }
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
                LabeledContent("Accessibility") {
                    if model.accessibilityGranted {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Open Settings…") { Permissions.request(.accessibility) }
                    }
                }
                LabeledContent("Screen Recording") {
                    if model.screenRecordingGranted {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Open Settings…") { Permissions.request(.screenRecording) }
                    }
                }
                if model.unstableSignature {
                    Text("This copy is ad-hoc signed, so macOS forgets these permissions whenever Shotty is rebuilt or updated. Build with scripts/setup-signing.sh to keep them.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
