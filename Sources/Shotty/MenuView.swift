import SwiftUI

/// The menu bar panel. Follows the look of Control Center and other system menu bar extras:
/// the window's own translucent material, quiet grouped sections, native controls.
struct MenuView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 12) {
                if !model.accessibilityGranted {
                    Callout(symbol: "hand.raised.fill", tint: .orange,
                            text: "Allow Accessibility so Shotty can paste into other apps.",
                            action: "Allow…") { Sender.requestAccessibility() }
                }
                if model.thumbnailSlowsCaptures {
                    Callout(symbol: "timer", tint: .yellow,
                            text: "macOS holds each screenshot about 5 seconds for its floating thumbnail.",
                            action: "Make Instant") { model.makeCapturesInstant() }
                }
                destinationSection
                promptSection
                captureButtons
                historySection
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Divider()
            footer
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(width: 320)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            LogoPlaceholder(size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text("Shotty").font(.system(size: 13, weight: .semibold))
                Text(model.enabled ? "Watching \(model.folder.lastPathComponent)" : "Paused")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Watch for screenshots", isOn: $model.enabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    // MARK: Destination

    /// One quiet row: where the next capture goes. Defaults to the app you were just using.
    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Sends To")
            HStack(spacing: 10) {
                Group {
                    if let icon = model.target?.icon {
                        Image(nsImage: icon).resizable().interpolation(.high)
                    } else {
                        Image(systemName: "macwindow").font(.system(size: 18)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.target?.name ?? "The app you're using")
                        .font(.system(size: 13, weight: .medium))
                    Text(model.followFrontmost ? "Last app you used" : "Always this app")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let target = model.target {
                    Picker("Paste as", selection: Binding(
                        get: { target.delivery },
                        set: { model.setDelivery($0, for: target) }
                    )) {
                        ForEach(Delivery.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .controlSize(.small)
                    .help("Attachment pastes the image (chat apps). File path pastes its path (Claude Code, Codex CLI). Remembered per app.")
                }
                destinationMenu
            }
            .padding(8)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
        }
    }

    private var destinationMenu: some View {
        Menu {
            Toggle("The App I Was Using", isOn: $model.followFrontmost)
            Divider()
            Section("Always Send To") {
                ForEach(model.availableTargets) { target in
                    Button {
                        model.targetID = target.bundleID
                        model.followFrontmost = false
                    } label: {
                        if !model.followFrontmost && model.fixedTarget?.bundleID == target.bundleID {
                            Label(target.name, systemImage: "checkmark")
                        } else {
                            Text(target.name)
                        }
                    }
                }
                Button("Other App…") { model.addCustomTarget() }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Choose where captures go")
    }

    // MARK: Prompt

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Prompt")
            TextField("Optional, e.g. “Fix what's wrong here”", text: $model.prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .controlSize(.regular)
            Toggle("Send automatically", isOn: $model.autoSend)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .help("Press Return after pasting.")
        }
    }

    // MARK: Capture

    private var captureButtons: some View {
        HStack(spacing: 8) {
            Button {
                model.instantCapture()
            } label: {
                HStack {
                    Label("Capture", systemImage: "camera.viewfinder")
                    Spacer(minLength: 4)
                    Text(InstantCapture.shortcutLabel).foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .help("Select an area, or press Space for a window. Sent the moment you let go.")

            Button {
                model.sendLatest()
            } label: {
                Label("Send Latest", systemImage: "paperplane")
            }
            .buttonStyle(.bordered)
            .disabled(model.isSending)
        }
        .controlSize(.large)
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(model.recent.isEmpty ? "History" : "History · \(model.recent.count)")
                Spacer()
                if let status = model.status {
                    Text(status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if model.recent.isEmpty {
                Text("Every screenshot and recording is kept here. Drag one into any app, or click ↻ to send it again.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.recent.enumerated()), id: \.element.id) { index, capture in
                            if index > 0 { Divider().padding(.leading, 60) }
                            CaptureRow(capture: capture, model: model)
                        }
                    }
                }
                .scrollIndicators(.automatic)
                .frame(height: min(CGFloat(model.recent.count) * 45, 230))
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 2) {
            MenuRowButton(title: "Settings…", shortcut: "⌘,") {
                NSApp.activate()
                openSettings()
            }
            .keyboardShortcut(",")
            Spacer()
            MenuRowButton(title: "Quit Shotty", shortcut: "⌘Q") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

// MARK: - Pieces

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
    }
}

private struct Callout: View {
    let symbol: String
    let tint: Color
    let text: String
    let action: String
    let perform: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint).font(.system(size: 13))
            VStack(alignment: .leading, spacing: 6) {
                Text(text).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                Button(action, action: perform).controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 8))
    }
}

/// Footer button that highlights on hover like a menu item.
private struct MenuRowButton: View {
    let title: String
    let shortcut: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text(shortcut).foregroundStyle(hovering ? .white.opacity(0.7) : .secondary)
            }
            .font(.system(size: 12))
            .foregroundStyle(hovering ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(hovering ? Color.accentColor : .clear, in: .rect(cornerRadius: 5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// A history row. Drag it out to drop the file into any app.
private struct CaptureRow: View {
    let capture: Capture
    let model: AppModel
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 42, height: 30)
                .clipShape(.rect(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator, lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(capture.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Group {
                    if !capture.exists {
                        Text("File moved or deleted")
                    } else if let error = capture.error {
                        Text(error).foregroundStyle(.red)
                    } else if let sent = capture.sentTo {
                        Text("\(sent) · \(capture.date, format: .relative(presentation: .named))")
                    } else {
                        Text(capture.date, format: .relative(presentation: .named))
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            if hovering && capture.exists {
                HStack(spacing: 2) {
                    Button { model.send(capture.url) } label: { Image(systemName: "arrow.clockwise") }
                        .help("Send again to \(model.target?.name ?? "the current app")")
                    Button { NSWorkspace.shared.activateFileViewerSelecting([capture.url]) } label: { Image(systemName: "folder") }
                        .help("Show in Finder")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(hovering ? Color.primary.opacity(0.06) : .clear)
        .opacity(capture.exists ? 1 : 0.5)
        .contentShape(.rect)
        .onHover { hovering = $0 }
        .onDrag {
            NSItemProvider(contentsOf: capture.url) ?? NSItemProvider(object: capture.url as NSURL)
        } preview: {
            thumbnail.frame(width: 120, height: 80).clipShape(.rect(cornerRadius: 6))
        }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(capture.url) }
        .contextMenu {
            Button("Send to \(model.target?.name ?? "Current App")") { model.send(capture.url) }
            Button("Copy") { model.copyToClipboard(capture) }
            Button("Open") { NSWorkspace.shared.open(capture.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([capture.url]) }
            Divider()
            Button("Remove from History") { model.removeFromHistory(capture) }
            Button("Clear History", role: .destructive) { model.clearHistory() }
        }
        .help("Drag into any app · double-click to open")
    }

    @ViewBuilder private var thumbnail: some View {
        if !capture.isMovie, let image = Thumbnails.image(for: capture.url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: capture.isMovie ? "video.fill" : "photo").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}

/// Stand-in mark until the final logo arrives.
struct LogoPlaceholder: View {
    var size: CGFloat = 26
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28)
            .fill(Color.accentColor.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}
