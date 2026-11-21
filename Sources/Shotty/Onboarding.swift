import SwiftUI

/// First-launch walkthrough (spec 0007). Shown once; reopen it from Help → Show Welcome….
/// Reset with: `defaults delete com.remidiy.shotty hasSeenWelcome`
enum Onboarding {
    static let seenKey = "hasSeenWelcome"
    static var shouldShow: Bool { !UserDefaults.standard.bool(forKey: seenKey) }
    static func markSeen() { UserDefaults.standard.set(true, forKey: seenKey) }
}

struct OnboardingView: View {
    @Bindable var model: AppModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var page: Page

    enum Page: Int, CaseIterable { case welcome, target, accessibility, folder, shortcuts }

    init(model: AppModel) {
        self.model = model
        // `--welcome-page N` opens a given page (used for screenshots).
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--welcome-page"), i + 1 < args.count, let n = Int(args[i + 1]), let p = Page(rawValue: n) {
            _page = State(initialValue: p)
        } else {
            _page = State(initialValue: .welcome)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ShottyMark(size: 64, animated: true, idleBlinks: true)
                .shadow(color: Color(red: 0.2, green: 0.36, blue: 0.96).opacity(0.25), radius: 10, y: 4)
                .padding(.top, 36)
                .padding(.bottom, 18)

            Group {
                switch page {
                case .welcome: WelcomePage()
                case .target: TargetPage(model: model)
                case .accessibility: AccessibilityPage(model: model)
                case .folder: FolderPage(model: model)
                case .shortcuts: ShortcutsPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 44)
            .transition(.opacity)
            .id(page)

            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .frame(width: 560, height: 520)
        .containerBackground(.regularMaterial, for: .window)
        .animation(.easeInOut(duration: 0.2), value: page)
        .onAppear { DockPolicy.windowAppeared() }
        .onDisappear { Onboarding.markSeen() }
    }

    private var footer: some View {
        HStack {
            if page == .shortcuts {
                Color.clear.frame(width: 1, height: 1)
            } else {
                Button("Skip") { finish() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(Page.allCases, id: \.self) { p in
                    Circle()
                        .fill(p == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Page \(page.rawValue + 1) of \(Page.allCases.count)")
            Spacer()
            HStack(spacing: 8) {
                if page != .welcome {
                    Button("Back") { page = Page(rawValue: page.rawValue - 1) ?? .welcome }
                }
                if page == .shortcuts {
                    Button("Get Started") { finish(openMain: true) }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Continue") { page = Page(rawValue: page.rawValue + 1) ?? .shortcuts }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)
        }
    }

    private func finish(openMain: Bool = false) {
        Onboarding.markSeen()
        dismissWindow(id: SceneID.welcome)
        if openMain { openWindow(id: SceneID.main) }
    }
}

// MARK: - Pages

private struct PageHeader: View {
    let title: String
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.title.weight(.semibold)).multilineTextAlignment(.center)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 20)
    }
}

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Welcome to Shotty",
                       text: "Take a screenshot and it lands in your agent: Claude, Codex, Cursor or a terminal. No saving, finding or dragging.")
            HStack(spacing: 14) {
                Step(symbol: "camera.viewfinder", title: "Capture", caption: "⇧⌘4 or ⌃⇧4")
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                Step(symbol: "paperplane", title: "Shotty sends", caption: "Pastes for you")
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                Step(symbol: "bubble.left.and.text.bubble.right", title: "In your agent", caption: "Ready to ask")
            }
            Text("Shotty lives in the menu bar. This window opens the full app whenever you need it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
        }
    }

    private struct Step: View {
        let symbol: String
        let title: String
        let caption: String
        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 52, height: 52)
                    .background(Color.accentColor.opacity(0.1), in: .rect(cornerRadius: 12))
                Text(title).font(.callout.weight(.medium))
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 110)
        }
    }
}

private struct TargetPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Where should shots go?",
                       text: "By default Shotty sends to the app you were just using. You can also pin one app.")
            ScrollView {
                VStack(spacing: 0) {
                    OptionRow(selected: model.followFrontmost, action: { model.followFrontmost = true }) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.system(size: 20)).foregroundStyle(Color.accentColor)
                            .frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("The app I was using")
                            Text("Recommended").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(model.availableTargets) { target in
                        Divider().padding(.leading, 48)
                        OptionRow(selected: !model.followFrontmost && model.fixedTarget?.bundleID == target.bundleID,
                                  action: { model.targetID = target.bundleID; model.followFrontmost = false }) {
                            Group {
                                if let icon = target.icon { Image(nsImage: icon).resizable() } else { Image(systemName: target.symbol) }
                            }
                            .frame(width: 26, height: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(target.name)
                                Text("Pastes as \(target.delivery.label.lowercased())").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .background(.background.opacity(0.6), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
            }
            .frame(maxHeight: 250)
            Button("Other App…") { model.addCustomTarget() }
                .buttonStyle(.link)
                .padding(.top, 10)
        }
    }

    private struct OptionRow<Label: View>: View {
        let selected: Bool
        let action: () -> Void
        @ViewBuilder var label: Label
        var body: some View {
            Button(action: action) {
                HStack(spacing: 10) {
                    label
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct AccessibilityPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Allow Shotty to paste",
                       text: "Shotty presses ⌘V (and Return, if you want) in the app you picked. macOS calls this Accessibility access.")
            StatusBox(granted: model.accessibilityGranted,
                      grantedText: "Accessibility is on. You're set.",
                      pendingText: "Turn on Shotty in Privacy & Security → Accessibility. This page updates by itself.")
            if !model.accessibilityGranted {
                Button("Open Accessibility Settings") { Permissions.request(.accessibility) }
                    .controlSize(.large)
                    .padding(.top, 16)
                Text("Already on but not detected? Turn Shotty off and on again in the list.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .task {
            // Live check while this page is visible.
            while !Task.isCancelled {
                let trusted = Permissions.accessibility
                if trusted != model.accessibilityGranted { model.accessibilityGranted = trusted }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct FolderPage: View {
    @Bindable var model: AppModel
    @State private var canRead = true

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Your screenshot folder",
                       text: "Shotty watches the folder macOS saves screenshots to. If macOS asks, allow access to it.")
            StatusBox(granted: canRead,
                      grantedText: "Watching \(model.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))",
                      pendingText: "Shotty can't read \(model.folder.lastPathComponent) yet. Allow it in Privacy & Security → Files & Folders.")
            StatusBox(granted: !model.thumbnailSlowsCaptures,
                      grantedText: "Floating Thumbnail is off, so screenshots send instantly.",
                      pendingText: "macOS holds each screenshot ~5 seconds for its Floating Thumbnail. Turn it off in ⇧⌘5 → Options, or here:")
                .padding(.top, 10)
            if model.thumbnailSlowsCaptures {
                Button("Make Screenshots Instant") { model.makeCapturesInstant() }
                    .controlSize(.large)
                    .padding(.top, 14)
            }
        }
        .onAppear { check() }
    }

    private func check() {
        if model.isDemo { canRead = true; return }
        canRead = (try? FileManager.default.contentsOfDirectory(atPath: model.folder.path)) != nil
    }
}

private struct ShortcutsPage: View {
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Shortcuts to remember",
                       text: "Use the screenshot keys you already know. Shotty picks up every capture.")
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                row("⇧⌘3", "Whole screen")
                row("⇧⌘4", "Area, or Space for a window")
                row("⇧⌘5", "Screenshot and recording options")
                Divider().gridCellUnsizedAxes(.horizontal)
                row(InstantCapture.shortcutLabel, "Shotty's instant capture: sends the moment you let go")
            }
            .padding(16)
            .background(.background.opacity(0.6), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
        }
    }

    private func row(_ keys: String, _ text: String) -> some View {
        GridRow {
            Text(keys)
                .font(.system(.body, design: .rounded).weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: .rect(cornerRadius: 5))
                .gridColumnAlignment(.trailing)
            Text(text)
        }
    }
}

private struct StatusBox: View {
    let granted: Bool
    let grantedText: String
    let pendingText: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 18))
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
            Text(granted ? grantedText : pendingText)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((granted ? Color.green : Color.secondary).opacity(0.1), in: .rect(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.2), value: granted)
    }
}
