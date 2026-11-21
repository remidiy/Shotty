import SwiftUI
import UniformTypeIdentifiers

/// The full app window (spec 0007): a sidebar with Home, History, Targets and Settings.
struct MainWindow: View {
    @Bindable var model: AppModel
    @State private var section: Section?

    init(model: AppModel) {
        self.model = model
        // `--section history` opens a given section (used for screenshots).
        let args = CommandLine.arguments
        let start = args.firstIndex(of: "--section").flatMap { i in i + 1 < args.count ? Section(rawValue: args[i + 1]) : nil }
        _section = State(initialValue: start ?? .home)
    }

    enum Section: String, CaseIterable, Identifiable {
        case home, history, targets, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .home: "Home"
            case .history: "History"
            case .targets: "Targets"
            case .settings: "Settings"
            }
        }
        var symbol: String {
            switch self {
            case .home: "house"
            case .history: "clock.arrow.circlepath"
            case .targets: "paperplane"
            case .settings: "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(Section.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .badge(item == .history && !model.recent.isEmpty ? model.recent.count : 0)
                        .tag(item)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            .safeAreaInset(edge: .bottom) { sidebarFooter }
        } detail: {
            switch section ?? .home {
            case .home: HomePane(model: model, section: $section)
            case .history: HistoryPane(model: model)
            case .targets: TargetsPane(model: model)
            case .settings: SettingsForm(model: model).navigationTitle("Settings")
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear { DockPolicy.windowAppeared() }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.enabled ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
            Text(model.enabled ? "Watching" : "Paused")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("Watch for screenshots", isOn: $model.enabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Home

private struct HomePane: View {
    @Bindable var model: AppModel
    @Binding var section: MainWindow.Section?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !model.accessibilityGranted {
                    Callout(symbol: "hand.raised.fill", tint: .orange,
                            text: "Allow Accessibility so Shotty can paste into other apps. If it's already on in System Settings, turn it off and on again.",
                            action: "Open Settings…") { Permissions.request(.accessibility) }
                }
                if model.thumbnailSlowsCaptures {
                    Callout(symbol: "timer", tint: .yellow,
                            text: "macOS holds each screenshot about 5 seconds for its floating thumbnail.",
                            action: "Make Instant") { model.makeCapturesInstant() }
                }
                HStack(alignment: .top, spacing: 14) {
                    statusCard
                    targetCard
                }
                actions
                recentSection
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Home")
    }

    private var header: some View {
        HStack(spacing: 14) {
            ShottyMark(size: 48)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Shotty").font(.title2.weight(.semibold))
                Text("Take a screenshot and it lands in your agent.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusCard: some View {
        Card {
            HStack {
                Label(model.enabled ? "On" : "Paused", systemImage: model.enabled ? "eye" : "pause.circle")
                    .font(.headline)
                    .foregroundStyle(model.enabled ? Color.primary : Color.secondary)
                Spacer()
                Toggle("Watch for screenshots", isOn: $model.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            Text(model.enabled
                 ? "Watching \(model.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))"
                 : "New screenshots stay where they are until you turn Shotty back on.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let status = model.status {
                Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var targetCard: some View {
        Card {
            HStack(spacing: 10) {
                Group {
                    if let icon = model.target?.icon {
                        Image(nsImage: icon).resizable().interpolation(.high)
                    } else {
                        Image(systemName: "macwindow").font(.system(size: 22)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.target?.name ?? "The app you're using").font(.headline)
                    Text(model.followFrontmost ? "Sends to the last app you used" : "Always sends here")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack {
                if let target = model.target {
                    Text("Pastes as \(target.delivery.label.lowercased())")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Change…") { section = .targets }
                    .controlSize(.small)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                model.instantCapture()
            } label: {
                Label("Capture \(InstantCapture.shortcutLabel)", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            Button {
                model.sendLatest()
            } label: {
                Label("Send Latest", systemImage: "paperplane")
            }
            .disabled(model.isSending)
            Spacer()
        }
        .controlSize(.large)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Captures").font(.headline)
                Spacer()
                if !model.recent.isEmpty {
                    Button("Show All") { section = .history }
                        .buttonStyle(.link)
                }
            }
            if model.recent.isEmpty {
                ContentUnavailableView("No Captures Yet",
                                       systemImage: "photo.on.rectangle",
                                       description: Text("Press ⇧⌘4 or \(InstantCapture.shortcutLabel). Your captures show up here."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)], spacing: 12) {
                    ForEach(model.recent.prefix(6)) { capture in
                        CaptureTile(capture: capture, model: model)
                    }
                }
            }
        }
    }
}

/// A quiet grouped box like the ones in System Settings.
private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

/// A capture thumbnail for the Home grid. Draggable into any app.
private struct CaptureTile: View {
    let capture: Capture
    let model: AppModel
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .overlay { CaptureThumbnail(capture: capture, maxPixel: 440) }
                .clipShape(.rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 0.5))
                .overlay(alignment: .topTrailing) {
                    if hovering && capture.exists {
                        Button { model.send(capture.url) } label: {
                            Image(systemName: "arrow.clockwise")
                                .padding(5)
                                .background(.regularMaterial, in: .circle)
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .help("Send again to \(model.target?.name ?? "the current app")")
                    }
                }
            Text(capture.title).font(.caption).lineLimit(1).truncationMode(.middle)
            CaptureSubtitle(capture: capture).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .opacity(capture.exists ? 1 : 0.5)
        .onHover { hovering = $0 }
        .draggable(capture)
        .onTapGesture(count: 2) { NSWorkspace.shared.open(capture.url) }
        .contextMenu { CaptureMenu(capture: capture, model: model) }
    }
}

// MARK: - History

private struct HistoryPane: View {
    @Bindable var model: AppModel
    @State private var query = ""
    @State private var selection: Capture.ID?

    private var items: [Capture] {
        query.isEmpty ? model.recent : model.recent.filter {
            $0.title.localizedCaseInsensitiveContains(query) || ($0.sentTo ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if model.recent.isEmpty {
                ContentUnavailableView("No Captures Yet", systemImage: "clock.arrow.circlepath",
                                       description: Text("Every screenshot and recording Shotty sees is kept here."))
            } else {
                List(selection: $selection) {
                    ForEach(items) { capture in
                        HistoryRow(capture: capture, model: model)
                            .tag(capture.id)
                            .draggable(capture)
                            .contextMenu { CaptureMenu(capture: capture, model: model) }
                    }
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds(.disabled)
                .searchable(text: $query, placement: .toolbar, prompt: "Search captures")
                .overlay {
                    if items.isEmpty { ContentUnavailableView.search(text: query) }
                }
            }
        }
        .navigationTitle("History")
        .navigationSubtitle(model.recent.isEmpty ? "" : "\(model.recent.count) captures · drag one into any app")
        .toolbar {
            ToolbarItem {
                Button {
                    if let c = model.recent.first(where: { $0.id == selection }) { model.send(c.url) }
                } label: { Label("Send Again", systemImage: "arrow.clockwise") }
                .disabled(selection == nil)
                .help("Send the selected capture again")
            }
            ToolbarItem {
                Button(role: .destructive) { model.clearHistory() } label: { Label("Clear History", systemImage: "trash") }
                    .disabled(model.recent.isEmpty)
                    .help("Clear History")
            }
        }
    }
}

private struct HistoryRow: View {
    let capture: Capture
    let model: AppModel
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 72, height: 48)
                .overlay { CaptureThumbnail(capture: capture, maxPixel: 200) }
                .clipShape(.rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(capture.title).lineLimit(1).truncationMode(.middle)
                CaptureSubtitle(capture: capture).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if capture.exists {
                HStack(spacing: 4) {
                    Button { model.send(capture.url) } label: { Image(systemName: "arrow.clockwise") }
                        .help("Send again to \(model.target?.name ?? "the current app")")
                    Button { NSWorkspace.shared.activateFileViewerSelecting([capture.url]) } label: { Image(systemName: "folder") }
                        .help("Show in Finder")
                }
                .buttonStyle(.borderless)
                .opacity(hovering ? 1 : 0)
            }
        }
        .padding(.vertical, 3)
        .opacity(capture.exists ? 1 : 0.5)
        .contentShape(.rect)
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(capture.url) }
    }
}

private struct CaptureThumbnail: View {
    let capture: Capture
    var maxPixel = 200
    var body: some View {
        if !capture.isMovie, let image = Thumbnails.image(for: capture.url, maxPixel: maxPixel) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: capture.isMovie ? "video.fill" : "photo").foregroundStyle(.secondary)
            }
        }
    }
}

private struct CaptureSubtitle: View {
    let capture: Capture
    var body: some View {
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
}

private struct CaptureMenu: View {
    let capture: Capture
    let model: AppModel
    var body: some View {
        Button("Send to \(model.target?.name ?? "Current App")") { model.send(capture.url) }
        Button("Copy") { model.copyToClipboard(capture) }
        Button("Open") { NSWorkspace.shared.open(capture.url) }
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([capture.url]) }
        Divider()
        Button("Remove from History") { model.removeFromHistory(capture) }
        Button("Clear History", role: .destructive) { model.clearHistory() }
    }
}

extension Capture: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .fileURL) { capture in
            SentTransferredFile(capture.url)
        }
        ProxyRepresentation { $0.url }
    }
}

// MARK: - Targets

private struct TargetsPane: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $model.followFrontmost) {
                    Text("Send to the app I was using")
                    Text("Work in Cursor and the shot lands in Cursor. Switch apps and it follows you.")
                }
            }

            Section {
                ForEach(model.availableTargets) { target in
                    TargetRow(target: target, model: model)
                }
                Button("Add App…") { model.addCustomTarget() }
            } header: {
                Text(model.followFrontmost ? "Apps" : "Always Send To")
            } footer: {
                Text("Attachment pastes the image itself (chat apps). File path pastes its path, which Claude Code and Codex CLI read in a terminal. Remembered per app.")
                    .foregroundStyle(.secondary)
            }

            Section("With Each Capture") {
                TextField("Prompt", text: $model.prompt, prompt: Text("Optional, e.g. “Fix what's wrong here”"), axis: .vertical)
                    .lineLimit(1...3)
                Toggle("Send automatically (press Return)", isOn: $model.autoSend)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Targets")
    }
}

private struct TargetRow: View {
    let target: Target
    @Bindable var model: AppModel

    private var isDefault: Bool { !model.followFrontmost && model.fixedTarget?.bundleID == target.bundleID }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = target.icon {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: target.symbol).foregroundStyle(.secondary)
                }
            }
            .frame(width: 26, height: 26)
            Text(target.name)
            if target.isCustom {
                Button { model.removeCustomTarget(target) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove \(target.name)")
            }
            Spacer()
            Picker("Paste as", selection: Binding(
                get: { target.delivery },
                set: { model.setDelivery($0, for: target) }
            )) {
                ForEach(Delivery.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            if isDefault {
                Image(systemName: "checkmark").foregroundStyle(Color.accentColor).fontWeight(.semibold)
                    .frame(width: 70)
            } else {
                Button("Use") {
                    model.targetID = target.bundleID
                    model.followFrontmost = false
                }
                .frame(width: 70)
            }
        }
    }
}
