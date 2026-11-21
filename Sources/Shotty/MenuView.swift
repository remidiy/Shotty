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
                targetSection
                promptSection
                captureButtons
                recentSection
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

    // MARK: Target

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Send To")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(model.availableTargets) { target in
                    TargetTile(target: target, selected: target.bundleID == model.target?.bundleID) {
                        model.targetID = target.bundleID
                    }
                    .contextMenu {
                        if target.isCustom {
                            Button("Remove \(target.name)", role: .destructive) { model.removeCustomTarget(target) }
                        }
                    }
                }
                AddTile { model.addCustomTarget() }
            }
            if let target = model.target {
                Picker("Paste as", selection: Binding(
                    get: { target.delivery },
                    set: { model.setDelivery($0, for: target) }
                )) {
                    ForEach(Delivery.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
                .help("Attachment pastes the image itself (chat apps). File path pastes its path (Claude Code, Codex CLI).")
            }
        }
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

    // MARK: Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel("Recent")
                Spacer()
                if let status = model.status {
                    Text(status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if model.recent.isEmpty {
                Text("Screenshots and recordings you take show up here and go straight to \(model.target?.name ?? "your app").")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.recent.prefix(4).enumerated()), id: \.element.id) { index, capture in
                        if index > 0 { Divider().padding(.leading, 52) }
                        CaptureRow(capture: capture) { model.send(capture.url) }
                    }
                }
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
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

/// A Control Center–style tile: app icon over its name, accent ring when selected.
private struct TargetTile: View {
    let target: Target
    let selected: Bool
    let select: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            VStack(spacing: 4) {
                Group {
                    if let icon = target.icon {
                        Image(nsImage: icon).resizable().interpolation(.high)
                    } else {
                        Image(systemName: target.symbol).font(.system(size: 18))
                    }
                }
                .frame(width: 28, height: 28)
                Text(target.name)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(background, in: .rect(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
            }
            .contentShape(.rect(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(target.name)
    }

    private var background: AnyShapeStyle {
        if selected { return AnyShapeStyle(Color.accentColor.opacity(0.14)) }
        return AnyShapeStyle(.quaternary.opacity(hovering ? 0.9 : 0.5))
    }
}

private struct AddTile: View {
    let add: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: add) {
            VStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 15, weight: .medium)).frame(width: 28, height: 28)
                Text("Other…").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(hovering ? 0.9 : 0.5), in: .rect(cornerRadius: 9))
            .contentShape(.rect(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Add any app")
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

private struct CaptureRow: View {
    let capture: Capture
    let resend: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 34, height: 24)
                .clipShape(.rect(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator, lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(capture.url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Group {
                    if let error = capture.error {
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
            Button(action: resend) {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(.borderless)
            .opacity(hovering ? 1 : 0)
            .help("Send again")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(hovering ? Color.primary.opacity(0.05) : .clear)
        .contentShape(.rect)
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { NSWorkspace.shared.activateFileViewerSelecting([capture.url]) }
        .help("Double-click to show in Finder")
    }

    @ViewBuilder private var thumbnail: some View {
        if !capture.isMovie, let image = NSImage(contentsOf: capture.url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: capture.isMovie ? "video.fill" : "photo").font(.system(size: 10)).foregroundStyle(.secondary)
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
