import SwiftUI

struct MenuView: View {
    @Bindable var model: AppModel
    @State private var showMore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !model.accessibilityGranted { accessibilityBanner }
            targetSection
            promptSection
            recentSection
            if showMore { moreSection }
            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            BotFace(size: 30, faceColor: .accentColor, eyeColor: .white)
            VStack(alignment: .leading, spacing: 1) {
                Text("Shotty").font(.headline)
                Text(model.enabled ? "Watching \(model.folder.lastPathComponent)" : "Paused")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $model.enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(model.enabled ? "Pause watching" : "Resume watching")
        }
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
            Text("Allow Accessibility so Shotty can paste into other apps.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Allow") { Sender.requestAccessibility() }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
        }
        .padding(10)
        .glassEffect(.regular.tint(.orange.opacity(0.18)), in: .rect(cornerRadius: 14))
    }

    // MARK: - Target

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send to").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            GlassEffectContainer(spacing: 8) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(model.availableTargets) { target in
                        targetChip(target)
                    }
                    Button {
                        model.addCustomTarget()
                    } label: {
                        Label("Other…", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
            if let target = model.target {
                HStack {
                    Text("Paste as").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { target.delivery },
                        set: { model.setDelivery($0, for: target) }
                    )) {
                        ForEach(Delivery.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                }
                .help("Attachment pastes the image itself (chat apps). File path pastes its path (Claude Code, Codex CLI).")
            }
        }
    }

    @ViewBuilder
    private func targetChip(_ target: Target) -> some View {
        let selected = target.bundleID == model.target?.bundleID
        let button = Button {
            model.targetID = target.bundleID
        } label: {
            HStack(spacing: 6) {
                if let icon = target.icon {
                    Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                } else {
                    Image(systemName: target.symbol)
                }
                Text(target.name).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .contextMenu {
            if target.isCustom {
                Button("Remove \(target.name)", role: .destructive) { model.removeCustomTarget(target) }
            }
        }
        if selected {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.glass)
        }
    }

    // MARK: - Prompt

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt (optional)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField("e.g. What's wrong in this screenshot?", text: $model.prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
            Toggle("Press Return after pasting", isOn: $model.autoSend)
                .font(.callout)
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.sendLatest()
                } label: {
                    Label("Send latest", systemImage: "paperplane.fill")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(model.isSending)
            }
            if model.recent.isEmpty {
                Text("Take a screenshot (⇧⌘4) or recording (⇧⌘5) and it lands in \(model.target?.name ?? "your app").")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
            } else {
                VStack(spacing: 6) {
                    ForEach(model.recent.prefix(4)) { capture in
                        CaptureRow(capture: capture) { model.send(capture.url) }
                    }
                }
            }
            if let status = model.status {
                Text(status).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - More

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder")
                Text(model.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.caption).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Change…") { model.chooseFolder() }.controlSize(.small)
                if model.customFolderPath != nil {
                    Button("Default") { model.useSystemFolder() }.controlSize(.small)
                }
            }
            Toggle("Include screen recordings", isOn: $model.includeRecordings)
            Toggle("Only macOS screenshots (ignore other files)", isOn: $model.onlyScreenshots)
            Toggle("Restore my clipboard afterwards", isOn: $model.restoreClipboard)
            Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
        }
        .font(.callout)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(showMore ? "Less" : "Settings") {
                withAnimation(.snappy) { showMore.toggle() }
            }
            .buttonStyle(.glass)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.glass)
                .keyboardShortcut("q")
        }
        .controlSize(.small)
    }
}

private struct CaptureRow: View {
    let capture: Capture
    let resend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 44, height: 30)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(capture.url.lastPathComponent).font(.caption).lineLimit(1).truncationMode(.middle)
                Group {
                    if let error = capture.error {
                        Text(error).foregroundStyle(.red)
                    } else if let sent = capture.sentTo {
                        Text("Sent to \(sent) · \(capture.date, style: .relative) ago")
                    } else {
                        Text(capture.date, style: .relative)
                    }
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: resend) { Image(systemName: "arrow.up.right") }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Send again")
        }
        .padding(8)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .onTapGesture(count: 2) { NSWorkspace.shared.activateFileViewerSelecting([capture.url]) }
    }

    @ViewBuilder private var thumbnail: some View {
        if !capture.isMovie, let image = NSImage(contentsOf: capture.url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            Image(nsImage: NSWorkspace.shared.icon(forFile: capture.url.path)).resizable().aspectRatio(contentMode: .fit)
        }
    }
}
